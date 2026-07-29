import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/kiosk_shell.dart';
import '../admin/admin_login_screen.dart';
import 'layout_select_screen.dart';

class TapToStartScreen extends StatelessWidget {
  const TapToStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return PopScope(
      canPop: false,
      child: KioskShell(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LayoutSelectScreen()),
            );
          },
          onLongPress: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminLoginScreen()),
            );
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrandMark(imagePath: controller.config.brandingPath, size: 280),
                  const SizedBox(height: 34),
                  Text(
                    controller.config.venueName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 50),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Make a little moment. Keep it forever.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: SkyeColors.ink),
                  ),
                  const SizedBox(height: 52),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 20),
                    decoration: BoxDecoration(
                      color: SkyeColors.blue,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(color: Color(0x3309549B), blurRadius: 24, offset: Offset(0, 10)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, color: Colors.white, size: 30),
                        SizedBox(width: 14),
                        Text('Tap anywhere to start',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

