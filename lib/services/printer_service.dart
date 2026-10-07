import 'package:flutter/services.dart';

import 'preprint_band_renderer.dart';

class BondedPrinter {
  const BondedPrinter({required this.name, required this.address});

  final String name;
  final String address;
}

class PrinterService {
  static const _channel = MethodChannel('com.skyeloop.kiosk/hardware');

  /// Whether this app run has already loaded the pre-print band into the
  /// printer's printhead-to-cutter gap. The band survives app restarts (the
  /// paper does not move), but the app cannot know that, so it primes once per
  /// run to guarantee the next strip has a header.
  bool _primed = false;

  bool get isPrimed => _primed;

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

  /// Sends [pngBytes] as the strip's photo/footer and [headerBytes] as the
  /// cafe-name band that fills the printer's printhead-to-cutter gap.
  ///
  /// The band is printed last and is NOT part of this strip: the printer cannot
  /// cut it off, so it stays inside and becomes the header of the next print.
  /// Call [ensurePreprintBand] first so the strip this photo is printed on
  /// already carries that header.
  Future<void> printImage({
    required Uint8List pngBytes,
    required Uint8List headerBytes,
    required int copies,
    required String? printerAddress,
    int darkness = 0,
    int gapDots = PreprintBandRenderer.gapDots,
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
      'headerBytes': headerBytes,
      'copies': copies,
      'address': printerAddress,
      'darkness': darkness,
      'gapDots': gapDots,
    });
  }

  /// Maintenance print: prints [maintenanceBytes] and loads [headerBytes] into
  /// the gap, so the next strip arrives with its header already on it.
  ///
  /// Run this at the start of a run and after loading a fresh roll. The slip it
  /// ejects is the paper that was already sitting between the printhead and the
  /// cutter, so it is expected to be blank above the maintenance text.
  Future<void> primePrinter({
    required Uint8List headerBytes,
    required Uint8List maintenanceBytes,
    required String? printerAddress,
    int darkness = 0,
    int gapDots = PreprintBandRenderer.gapDots,
  }) async {
    if (await isEmulator) {
      await Future<void>.delayed(const Duration(seconds: 2));
      _primed = true;
      return;
    }
    if (printerAddress == null) {
      throw StateError('No Bluetooth printer has been selected in Admin mode.');
    }
    await _channel.invokeMethod<void>('primePrinter', {
      'maintenanceBytes': maintenanceBytes,
      'headerBytes': headerBytes,
      'address': printerAddress,
      'darkness': darkness,
      'gapDots': gapDots,
    });
    _primed = true;
  }

  /// Loads the pre-print band once per app run. Returns true when a maintenance
  /// print was actually sent, so callers can tell the customer-facing flow why
  /// an extra slip came out.
  ///
  /// [maintenanceBytes] is a builder so its band is only rendered when a
  /// maintenance print is really due.
  Future<bool> ensurePreprintBand({
    required Uint8List headerBytes,
    required Future<Uint8List> Function() maintenanceBytes,
    required String? printerAddress,
    int darkness = 0,
    int gapDots = PreprintBandRenderer.gapDots,
  }) async {
    if (_primed) return false;
    await primePrinter(
      headerBytes: headerBytes,
      maintenanceBytes: await maintenanceBytes(),
      printerAddress: printerAddress,
      darkness: darkness,
      gapDots: gapDots,
    );
    return true;
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
