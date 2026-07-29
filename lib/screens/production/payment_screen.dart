import 'dart:io';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/back_to_start_button.dart';
import '../../widgets/kiosk_shell.dart';
import '../../widgets/screen_heading.dart';
import 'preview_edit_screen.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tier = app.session!.tier;
    final qrPath = app.config.paymentQrPaths[tier];
    final hasQr = qrPath != null && File(qrPath).existsSync();
    return PopScope(
      canPop: false,
      child: KioskShell(
        header: ScreenHeading(
          title: 'Pay ${tier.priceLabel}',
          subtitle: 'Scan the payment QR below. Tap Done after you have paid.',
        ),
        footer: const BackToStartButton(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: SkyeColors.blue, width: 3),
                          ),
                          child: hasQr
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Image.file(File(qrPath), fit: BoxFit.contain),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.qr_code_2_rounded, size: 180, color: SkyeColors.ink),
                                    Text('Payment QR placeholder',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                                    SizedBox(height: 6),
                                    Text('Upload this price tier in Admin mode.'),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: SkyeColors.mist, borderRadius: BorderRadius.circular(16)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: SkyeColors.blue),
                          SizedBox(width: 10),
                          Expanded(child: Text('Payment can take a moment to appear at the cashier. This button does not verify payment.')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const PreviewEditScreen()),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Done — I have paid'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
