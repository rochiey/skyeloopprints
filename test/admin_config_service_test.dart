import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyeloop/models/pricing_tier.dart';
import 'package:skyeloop/services/admin_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('payment test mode defaults to enabled', () async {
    final service = AdminConfigService();
    await service.initialize();

    final config = service.load();
    expect(config.paymentTestMode, isTrue);
  });

  test('saves and loads payment test mode', () async {
    final service = AdminConfigService();
    await service.initialize();

    await service.setPaymentTestMode(false);
    expect(service.load().paymentTestMode, isFalse);

    await service.setPaymentTestMode(true);
    expect(service.load().paymentTestMode, isTrue);
  });

  test('copies limit is disabled by default with tier defaults', () async {
    final service = AdminConfigService();
    await service.initialize();

    final config = service.load();
    expect(config.copiesLimitEnabled, isFalse);
    expect(config.maxCopiesFor(PricingTier.single), 1);
    expect(config.maxCopiesFor(PricingTier.strip), 3);
    expect(config.maxCopiesFor(PricingTier.grid), 5);
  });

  test('saves and loads copies limit toggle', () async {
    final service = AdminConfigService();
    await service.initialize();

    await service.setCopiesLimitEnabled(true);
    expect(service.load().copiesLimitEnabled, isTrue);

    await service.setCopiesLimitEnabled(false);
    expect(service.load().copiesLimitEnabled, isFalse);
  });

  test('saves and loads per-option maximum copies', () async {
    final service = AdminConfigService();
    await service.initialize();

    await service.setMaxCopies(tier: PricingTier.single, value: 2);
    await service.setMaxCopies(tier: PricingTier.strip, value: 7);
    await service.setMaxCopies(tier: PricingTier.grid, value: 4);

    final config = service.load();
    expect(config.maxCopiesFor(PricingTier.single), 2);
    expect(config.maxCopiesFor(PricingTier.strip), 7);
    expect(config.maxCopiesFor(PricingTier.grid), 4);
  });

  test('per-option maximum copies are clamped to 1..99', () async {
    final service = AdminConfigService();
    await service.initialize();

    await service.setMaxCopies(tier: PricingTier.strip, value: 0);
    expect(service.load().maxCopiesFor(PricingTier.strip), 1);

    await service.setMaxCopies(tier: PricingTier.strip, value: 250);
    expect(service.load().maxCopiesFor(PricingTier.strip), 99);
  });

  test('print output darkness defaults to the pipeline default', () async {
    final service = AdminConfigService();
    await service.initialize();

    expect(service.load().printDarkness, 0);
  });

  test('saves and loads print output darkness', () async {
    final service = AdminConfigService();
    await service.initialize();

    await service.setPrintDarkness(3);
    expect(service.load().printDarkness, 3);

    await service.setPrintDarkness(-2);
    expect(service.load().printDarkness, -2);

    // 0 restores the pipeline's built-in default output.
    await service.setPrintDarkness(0);
    expect(service.load().printDarkness, 0);
  });

  test('print output darkness is clamped to -5..5', () async {
    final service = AdminConfigService();
    await service.initialize();

    await service.setPrintDarkness(-9);
    expect(service.load().printDarkness, -5);

    await service.setPrintDarkness(9);
    expect(service.load().printDarkness, 5);
  });
}
