import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_config.dart';
import '../models/pricing_tier.dart';

class AdminConfigService {
  static const _venueKey = 'venue_name';
  static const _brandingKey = 'branding_path';
  static const _passwordSaltKey = 'admin_password_salt';
  static const _passwordHashKey = 'admin_password_hash';
  static const _printerAddressKey = 'printer_address';
  static const _printerNameKey = 'printer_name';

  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  bool get hasPassword => _preferences.containsKey(_passwordHashKey);

  AdminConfig load() {
    final qrPaths = <PricingTier, String>{};
    for (final tier in PricingTier.values) {
      final value = _preferences.getString(_qrKey(tier));
      if (value != null && File(value).existsSync()) qrPaths[tier] = value;
    }
    final branding = _preferences.getString(_brandingKey);
    return AdminConfig(
      venueName: _preferences.getString(_venueKey) ?? 'Skye Loop Vendo',
      brandingPath:
          branding != null && File(branding).existsSync() ? branding : null,
      paymentQrPaths: qrPaths,
      printerAddress: _preferences.getString(_printerAddressKey),
      printerName: _preferences.getString(_printerNameKey),
    );
  }

  Future<void> setVenueName(String value) async {
    final trimmed = value.trim();
    await _preferences.setString(
      _venueKey,
      trimmed.isEmpty ? 'Skye Loop Vendo' : trimmed,
    );
  }

  Future<String?> chooseAndSaveImage(String slotName) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    final sourcePath = result?.files.single.path;
    if (sourcePath == null) return null;

    final root = await getApplicationDocumentsDirectory();
    final assetsDirectory = Directory(p.join(root.path, 'venue_assets'));
    await assetsDirectory.create(recursive: true);
    final extension = p.extension(sourcePath).toLowerCase();
    final destination = p.join(
      assetsDirectory.path,
      '${slotName}_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    await File(sourcePath).copy(destination);
    return destination;
  }

  Future<void> setBrandingPath(String path) async {
    await _preferences.setString(_brandingKey, path);
  }

  Future<void> setPaymentQrPath(PricingTier tier, String path) async {
    await _preferences.setString(_qrKey(tier), path);
  }

  Future<void> setPrinter({required String address, required String name}) async {
    await _preferences.setString(_printerAddressKey, address);
    await _preferences.setString(_printerNameKey, name);
  }

  Future<void> setPassword(String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(24, (_) => random.nextInt(256));
    final encodedSalt = base64UrlEncode(salt);
    final passwordHash = _derivePasswordHash(password, salt);
    await _preferences.setString(_passwordSaltKey, encodedSalt);
    await _preferences.setString(_passwordHashKey, passwordHash);
  }

  bool verifyPassword(String password) {
    final encodedSalt = _preferences.getString(_passwordSaltKey);
    final expected = _preferences.getString(_passwordHashKey);
    if (encodedSalt == null || expected == null) return false;
    final actual = _derivePasswordHash(password, base64Url.decode(encodedSalt));
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var index = 0; index < actual.length; index++) {
      difference |= actual.codeUnitAt(index) ^ expected.codeUnitAt(index);
    }
    return difference == 0;
  }

  String _derivePasswordHash(String password, List<int> salt) {
    var bytes = <int>[...salt, ...utf8.encode(password)];
    for (var round = 0; round < 60000; round++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64UrlEncode(bytes);
  }

  String _qrKey(PricingTier tier) => 'payment_qr_${tier.storageKey}';
}
