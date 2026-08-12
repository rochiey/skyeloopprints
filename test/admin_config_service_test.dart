import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyeloop/models/pricing_tier.dart';
import 'package:skyeloop/services/admin_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('skyeloop_config_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('saves and loads a bank transfer QR path per tier', () async {
    final service = AdminConfigService();
    await service.initialize();

    final gcashFile = File('${tempDir.path}/gcash.png');
    final bankFile = File('${tempDir.path}/bank.png');
    await gcashFile.writeAsBytes([1]);
    await bankFile.writeAsBytes([1]);

    await service.setPaymentQrPath(PricingTier.single, gcashFile.path);
    await service.setBankTransferQrPath(PricingTier.single, bankFile.path);

    final config = service.load();
    expect(config.paymentQrPaths[PricingTier.single], gcashFile.path);
    expect(config.bankTransferQrPaths[PricingTier.single], bankFile.path);
    expect(config.bankTransferQrPaths.containsKey(PricingTier.grid), isFalse);
  });

  test('keeps GCash QR when only a bank transfer QR is set', () async {
    final service = AdminConfigService();
    await service.initialize();

    final bankFile = File('${tempDir.path}/bank.png');
    await bankFile.writeAsBytes([1]);
    await service.setBankTransferQrPath(PricingTier.strip, bankFile.path);

    final config = service.load();
    expect(config.paymentQrPaths, isEmpty);
    expect(config.bankTransferQrPaths[PricingTier.strip], bankFile.path);
  });

  test('drops bank QR paths whose file no longer exists', () async {
    final service = AdminConfigService();
    await service.initialize();
    await service.setBankTransferQrPath(
        PricingTier.grid, '${tempDir.path}/missing.png');

    final config = service.load();
    expect(config.bankTransferQrPaths, isEmpty);
  });
}
