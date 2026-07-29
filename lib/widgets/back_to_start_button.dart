import 'package:flutter/material.dart';

import '../app.dart';
import '../screens/production/tap_to_start_screen.dart';

class BackToStartButton extends StatelessWidget {
  const BackToStartButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final controller = AppScope.of(context, listen: false);
        await controller.clearSession();
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const TapToStartScreen()),
          (_) => false,
        );
      },
      icon: const Icon(Icons.home_outlined),
      label: const Text('Back to Start'),
    );
  }
}

