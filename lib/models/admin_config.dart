class AdminConfig {
  const AdminConfig({
    this.venueName = 'Skye Loop Vendo',
    this.brandingPath,
    this.paymentTestMode = true,
    this.printerAddress,
    this.printerName,
  });

  final String venueName;
  final String? brandingPath;

  /// When true, the PayMongo live QR payment flow is bypassed so the kiosk
  /// camera and image preview can be tested without real payments.
  final bool paymentTestMode;
  final String? printerAddress;
  final String? printerName;

  AdminConfig copyWith({
    String? venueName,
    String? brandingPath,
    bool? paymentTestMode,
    String? printerAddress,
    String? printerName,
    bool clearPrinter = false,
  }) {
    return AdminConfig(
      venueName: venueName ?? this.venueName,
      brandingPath: brandingPath ?? this.brandingPath,
      paymentTestMode: paymentTestMode ?? this.paymentTestMode,
      printerAddress: clearPrinter ? null : printerAddress ?? this.printerAddress,
      printerName: clearPrinter ? null : printerName ?? this.printerName,
    );
  }
}

