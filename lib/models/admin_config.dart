import 'pricing_tier.dart';

class AdminConfig {
  const AdminConfig({
    this.venueName = 'Skye Loop Vendo',
    this.brandingPath,
    this.paymentTestMode = true,
    this.printerAddress,
    this.printerName,
    this.copiesLimitEnabled = false,
    this.maxCopiesSingle = 1,
    this.maxCopiesStrip = 3,
    this.maxCopiesGrid = 5,
  });

  final String venueName;
  final String? brandingPath;

  /// When true, the PayMongo live QR payment flow is bypassed so the kiosk
  /// camera and image preview can be tested without real payments.
  final bool paymentTestMode;
  final String? printerAddress;
  final String? printerName;

  /// When true, customers may print at most [maxCopiesFor] copies per option.
  /// When false, the copies stepper has no upper limit.
  final bool copiesLimitEnabled;
  final int maxCopiesSingle;
  final int maxCopiesStrip;
  final int maxCopiesGrid;

  AdminConfig copyWith({
    String? venueName,
    String? brandingPath,
    bool? paymentTestMode,
    String? printerAddress,
    String? printerName,
    bool? copiesLimitEnabled,
    int? maxCopiesSingle,
    int? maxCopiesStrip,
    int? maxCopiesGrid,
    bool clearPrinter = false,
  }) {
    return AdminConfig(
      venueName: venueName ?? this.venueName,
      brandingPath: brandingPath ?? this.brandingPath,
      paymentTestMode: paymentTestMode ?? this.paymentTestMode,
      printerAddress: clearPrinter ? null : printerAddress ?? this.printerAddress,
      printerName: clearPrinter ? null : printerName ?? this.printerName,
      copiesLimitEnabled: copiesLimitEnabled ?? this.copiesLimitEnabled,
      maxCopiesSingle: maxCopiesSingle ?? this.maxCopiesSingle,
      maxCopiesStrip: maxCopiesStrip ?? this.maxCopiesStrip,
      maxCopiesGrid: maxCopiesGrid ?? this.maxCopiesGrid,
    );
  }

  /// The configured maximum number of copies for [tier]'s layout option.
  /// Only enforced when [copiesLimitEnabled] is true.
  int maxCopiesFor(PricingTier tier) {
    return switch (tier) {
      PricingTier.single => maxCopiesSingle,
      PricingTier.strip => maxCopiesStrip,
      PricingTier.grid => maxCopiesGrid,
    };
  }
}

