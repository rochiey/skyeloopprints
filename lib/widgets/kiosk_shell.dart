import 'package:flutter/material.dart';

import '../theme/skyeloop_theme.dart';

class KioskShell extends StatelessWidget {
  const KioskShell({
    required this.child,
    this.header,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(32, 24, 32, 24),
    super.key,
  });

  final Widget child;
  final Widget? header;
  final Widget? footer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [SkyeColors.cream, SkyeColors.mist, Color(0xFFFFF7E3)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: padding,
            child: Column(
              children: [
                if (header != null) header!,
                Expanded(child: child),
                if (footer != null) footer!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

