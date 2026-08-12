import 'dart:io';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/back_to_start_button.dart';
import '../../widgets/kiosk_shell.dart';
import '../../widgets/screen_heading.dart';
import 'capture_screen.dart';

enum _PaymentMethod { gcash, bankTransfer }

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  _PaymentMethod _method = _PaymentMethod.gcash;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tier = app.session!.tier;
    final gcashPath = app.config.paymentQrPaths[tier];
    final bankPath = app.config.bankTransferQrPaths[tier];
    final hasGcash = gcashPath != null && File(gcashPath).existsSync();
    final hasBank = bankPath != null && File(bankPath).existsSync();
    final availableMethods = <_PaymentMethod>[
      if (hasGcash) _PaymentMethod.gcash,
      if (hasBank) _PaymentMethod.bankTransfer,
    ];
    final method = availableMethods.contains(_method) ? _method : _PaymentMethod.gcash;
    final qrPath = switch (method) {
      _PaymentMethod.gcash => gcashPath,
      _PaymentMethod.bankTransfer => bankPath,
    };
    final hasQr = qrPath != null && File(qrPath).existsSync();
    final subtitle = hasGcash && hasBank
        ? 'Scan the GCash or bank transfer QR below, then tap Done to start your photo session.'
        : 'Scan the payment QR below, then tap Done to start your photo session.';
    return PopScope(
      canPop: false,
      child: KioskShell(
        header: ScreenHeading(
          title: 'Pay ${tier.priceLabel}',
          subtitle: subtitle,
        ),
        footer: const BackToStartButton(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (availableMethods.length > 1) ...[
                        SegmentedButton<_PaymentMethod>(
                          segments: const [
                            ButtonSegment(
                              value: _PaymentMethod.gcash,
                              label: Text('GCash'),
                              icon: Icon(Icons.qr_code_2_rounded),
                            ),
                            ButtonSegment(
                              value: _PaymentMethod.bankTransfer,
                              label: Text('Bank transfer'),
                              icon: Icon(Icons.account_balance_rounded),
                            ),
                          ],
                          selected: {method},
                          onSelectionChanged: (selection) {
                            setState(() => _method = selection.first);
                          },
                          showSelectedIcon: false,
                        ),
                        const SizedBox(height: 20),
                      ],
                      AspectRatio(
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
                          MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Paid — Take photos'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
