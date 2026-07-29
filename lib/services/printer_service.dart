import 'package:flutter/services.dart';

class BondedPrinter {
  const BondedPrinter({required this.name, required this.address});

  final String name;
  final String address;
}

class PrinterService {
  static const _channel = MethodChannel('com.skyeloop.kiosk/hardware');

  Future<bool> get isEmulator async {
    try {
      return await _channel.invokeMethod<bool>('isEmulator') ?? false;
    } on MissingPluginException {
      return true;
    }
  }

  Future<List<BondedPrinter>> listBondedPrinters() async {
    final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
          'listBondedPrinters',
        ) ??
        const [];
    return raw
        .map(
          (entry) => BondedPrinter(
            name: entry['name']?.toString() ?? 'Bluetooth printer',
            address: entry['address']?.toString() ?? '',
          ),
        )
        .where((printer) => printer.address.isNotEmpty)
        .toList();
  }

  Future<void> printImage({
    required Uint8List pngBytes,
    required int copies,
    required String? printerAddress,
  }) async {
    if (await isEmulator) {
      await Future<void>.delayed(const Duration(seconds: 2));
      return;
    }
    if (printerAddress == null) {
      throw StateError('No Bluetooth printer has been selected in Admin mode.');
    }
    await _channel.invokeMethod<void>('printImage', {
      'pngBytes': pngBytes,
      'copies': copies,
      'address': printerAddress,
    });
  }

  Future<void> enterKioskMode() async {
    try {
      await _channel.invokeMethod<void>('enterKioskMode');
    } on PlatformException {
      // Screen pinning may be unavailable until the device is provisioned.
    } on MissingPluginException {
      // Widget tests and non-Android builds have no native channel.
    }
  }

  Future<void> leaveKioskMode() async {
    try {
      await _channel.invokeMethod<void>('leaveKioskMode');
    } on PlatformException {
      // Safe to ignore if lock task was not active.
    } on MissingPluginException {
      // Widget tests and non-Android builds have no native channel.
    }
  }
}
