import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/pricing_tier.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/back_to_start_button.dart';
import '../../widgets/kiosk_shell.dart';
import '../../widgets/screen_heading.dart';
import 'capture_screen.dart';

class LayoutSelectScreen extends StatelessWidget {
  const LayoutSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: KioskShell(
        header: const ScreenHeading(
          title: 'Choose your moment',
          subtitle: 'Pick the photo layout you would like to print.',
        ),
        footer: const BackToStartButton(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 760;
            final cards = PricingTier.values
                .map((tier) => Expanded(child: _TierCard(tier: tier)))
                .toList();
            return Center(
              child: horizontal
                  ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(cards))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(cards)),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _spaced(List<Widget> children) {
    return [
      for (var index = 0; index < children.length; index++) ...[
        children[index],
        if (index != children.length - 1) const SizedBox(width: 18, height: 18),
      ],
    ];
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier});

  final PricingTier tier;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AppScope.of(context, listen: false).beginSession(tier);
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LayoutIcon(tier: tier),
              const SizedBox(height: 18),
              Text(tier.title, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(tier.subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Chip(
                backgroundColor: SkyeColors.amber,
                label: Text(tier.priceLabel,
                    style: const TextStyle(color: SkyeColors.ink, fontSize: 22, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayoutIcon extends StatelessWidget {
  const _LayoutIcon({required this.tier});
  final PricingTier tier;

  @override
  Widget build(BuildContext context) {
    final cells = List<Widget>.generate(
      tier.shotCount,
      (_) => Container(decoration: BoxDecoration(color: SkyeColors.mist, borderRadius: BorderRadius.circular(8))),
    );
    return Container(
      width: 110,
      height: 135,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SkyeColors.ink, width: 2)),
      child: tier.layout == LayoutType.single
          ? cells.first
          : GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: tier.layout == LayoutType.grid ? 2 : 1,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              children: cells,
            ),
    );
  }
}

