import 'package:flutter_test/flutter_test.dart';
import 'package:skyeloop/models/pricing_tier.dart';

void main() {
  test('pricing tiers map to the required layout, count, and price', () {
    expect(PricingTier.single.shotCount, 1);
    expect(PricingTier.single.price, 20);
    expect(PricingTier.single.layout, LayoutType.single);

    expect(PricingTier.strip.shotCount, 3);
    expect(PricingTier.strip.price, 30);
    expect(PricingTier.strip.layout, LayoutType.strip);

    expect(PricingTier.grid.shotCount, 4);
    expect(PricingTier.grid.price, 50);
    expect(PricingTier.grid.layout, LayoutType.grid);
  });
}

