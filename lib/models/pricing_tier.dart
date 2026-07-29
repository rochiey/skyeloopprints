enum LayoutType { single, strip, grid }

enum PricingTier {
  single(
    layout: LayoutType.single,
    shotCount: 1,
    price: 20,
    title: 'One perfect shot',
    subtitle: 'Classic portrait',
  ),
  strip(
    layout: LayoutType.strip,
    shotCount: 3,
    price: 30,
    title: 'Three-photo strip',
    subtitle: 'Three moments in a row',
  ),
  grid(
    layout: LayoutType.grid,
    shotCount: 4,
    price: 50,
    title: 'Four-photo grid',
    subtitle: 'A full little story',
  );

  const PricingTier({
    required this.layout,
    required this.shotCount,
    required this.price,
    required this.title,
    required this.subtitle,
  });

  final LayoutType layout;
  final int shotCount;
  final int price;
  final String title;
  final String subtitle;

  String get priceLabel => '₱$price';
  String get storageKey => name;
}

