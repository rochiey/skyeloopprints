import 'pricing_tier.dart';

class AdminConfig {
  const AdminConfig({
    this.venueName = 'Skye Loop Vendo',
    this.brandingPath,
    this.paymentQrPaths = const {},
    this.printerAddress,
    this.printerName,
  });

  final String venueName;
  final String? brandingPath;
  final Map<PricingTier, String> paymentQrPaths;
  final String? printerAddress;
  final String? printerName;

  AdminConfig copyWith({
    String? venueName,
    String? brandingPath,
    Map<PricingTier, String>? paymentQrPaths,
    String? printerAddress,
    String? printerName,
    bool clearPrinter = false,
  }) {
    return AdminConfig(
      venueName: venueName ?? this.venueName,
      brandingPath: brandingPath ?? this.brandingPath,
      paymentQrPaths: paymentQrPaths ?? this.paymentQrPaths,
      printerAddress: clearPrinter ? null : printerAddress ?? this.printerAddress,
      printerName: clearPrinter ? null : printerName ?? this.printerName,
    );
  }
}

