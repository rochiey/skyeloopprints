import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../services/paymongo_service.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/back_to_start_button.dart';
import '../../widgets/kiosk_shell.dart';
import '../../widgets/screen_heading.dart';
import 'capture_screen.dart';

enum _LivePaymentState { creating, waiting, paid, failed, error }

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymongoService _paymongo = PaymongoService();
  Timer? _pollTimer;

  _LivePaymentState _state = _LivePaymentState.creating;
  PaymongoQrPayment? _payment;
  String? _errorMessage;
  String? _errorDetails;

  @override
  void initState() {
    super.initState();
    _createQrPayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createQrPayment() async {
    final app = AppScope.of(context, listen: false);
    final tier = app.session!.tier;
    setState(() {
      _state = _LivePaymentState.creating;
      _errorMessage = null;
      _errorDetails = null;
      _payment = null;
    });
    try {
      final payment = await _paymongo.createQrPhPayment(
        amountCentavos: tier.price * 100,
        description: 'SkyeLoop ${tier.title} (${tier.priceLabel})',
      );
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _state = payment.hasQrImage
            ? _LivePaymentState.waiting
            : _LivePaymentState.error;
        if (!payment.hasQrImage) {
          _errorMessage = 'PayMongo did not return a QR code. Try again.';
        }
      });
      if (payment.hasQrImage) {
        _startPolling(payment.intentId);
      }
    } on PaymongoException catch (error) {
      debugPrint('PayMongo error: $error');
      if (!mounted) return;
      setState(() {
        _state = _LivePaymentState.error;
        _errorMessage = error.message;
        _errorDetails = error.details;
      });
    } catch (error) {
      debugPrint('Payment network error: $error');
      if (!mounted) return;
      setState(() {
        _state = _LivePaymentState.error;
        _errorMessage = 'Could not reach PayMongo. Check the internet '
            'connection and try again.';
      });
    }
  }

  void _startPolling(String intentId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final payment = await _paymongo.retrievePayment(intentId);
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _payment = payment);
        if (payment.isSucceeded) {
          timer.cancel();
          setState(() => _state = _LivePaymentState.paid);
        }
      } catch (error) {
        // Transient errors: keep polling; the kiosk stays in the "waiting"
        // state until the payment intent resolves.
        debugPrint('PayMongo poll error: $error');
      }
    });
  }

  void _proceedToCapture() {
    _pollTimer?.cancel();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tier = app.session!.tier;
    final testMode = app.config.paymentTestMode;

    final subtitle = testMode
        ? 'Test mode is on: payment is bypassed for camera and preview testing.'
        : 'Scan the QR Ph code below with any bank or e-wallet app (GCash, Maya, '
            'and more). The session starts automatically once payment is confirmed.';

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
                      if (testMode)
                        _TestModeBody(onProceed: _proceedToCapture)
                      else
                        _LiveModeBody(
                          state: _state,
                          payment: _payment,
                          errorMessage: _errorMessage,
                          errorDetails: _errorDetails,
                          onRetry: _createQrPayment,
                          onProceed: _proceedToCapture,
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
/// Test-mode payment card: skips PayMongo entirely so the kiosk camera and
/// image preview can be exercised without a real payment.
class _TestModeBody extends StatelessWidget {
  const _TestModeBody({required this.onProceed});

  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SkyeColors.amber.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SkyeColors.amber, width: 2),
          ),
          child: const Row(
            children: [
              Icon(Icons.science_outlined, color: Colors.brown),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TEST MODE - PayMongo is bypassed. No QR is shown and no '
                  'payment is collected.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Icon(Icons.qr_code_scanner_rounded, size: 120, color: SkyeColors.mist),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onProceed,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Paid (test) - Take photos'),
        ),
      ],
    );
  }
}


/// Live-mode payment card: generates a dynamic QR Ph code through PayMongo
/// and only unlocks the session once the payment intent is `succeeded`.
class _LiveModeBody extends StatelessWidget {
  const _LiveModeBody({
    required this.state,
    required this.payment,
    required this.errorMessage,
    required this.errorDetails,
    required this.onRetry,
    required this.onProceed,
  });

  final _LivePaymentState state;
  final PaymongoQrPayment? payment;
  final String? errorMessage;
  final String? errorDetails;
  final VoidCallback onRetry;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: SkyeColors.blue, width: 3),
            ),
            child: _buildQrArea(),
          ),
        ),
        const SizedBox(height: 22),
        ..._buildStatusAndAction(context),
      ],
    );
  }

  Widget _buildQrArea() {
    if (state == _LivePaymentState.paid) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, size: 120, color: Colors.green),
          SizedBox(height: 10),
          Text('Payment received!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      );
    }
    if (state == _LivePaymentState.creating) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: SkyeColors.blue),
          SizedBox(height: 16),
          Text('Generating your QR Ph code...'),
        ],
      );
    }
    if (state == _LivePaymentState.error || state == _LivePaymentState.failed) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 100, color: SkyeColors.rose),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              errorMessage ?? 'The payment failed or was cancelled.',
              textAlign: TextAlign.center,
            ),
          ),
          if (errorDetails != null && errorDetails!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                errorDetails!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Generate a new QR'),
          ),
        ],
      );
    }
    final qrBytes = payment?.qrImageBytes;
    if (qrBytes == null || qrBytes.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 100, color: SkyeColors.rose),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'PayMongo did not return a QR code. Try again.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Generate a new QR'),
          ),
        ],
      );
    }
    // The QR Ph code comes ready-made from PayMongo as a PNG image.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Image.memory(
        qrBytes,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          size: 90,
          color: SkyeColors.rose,
        ),
      ),
    );
  }

  List<Widget> _buildStatusAndAction(BuildContext context) {
    switch (state) {
      case _LivePaymentState.paid:
        return [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, color: Colors.green),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Verified with PayMongo. Starting your session...',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onProceed,
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Start taking photos'),
          ),
        ];
      case _LivePaymentState.error:
      case _LivePaymentState.failed:
        return [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SkyeColors.rose.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: SkyeColors.rose),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage ??
                        'The payment failed or was cancelled. Generate a new '
                            'QR to try again.',
                  ),
                ),
              ],
            ),
          ),
        ];
      case _LivePaymentState.creating:
        return const [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Preparing the QR Ph code...'),
            ],
          ),
        ];
      case _LivePaymentState.waiting:
        return [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SkyeColors.mist,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: SkyeColors.blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Open any bank or e-wallet app (GCash, Maya, and more), '
                    'scan this QR Ph code, and pay. This screen unlocks '
                    'automatically once PayMongo confirms your payment.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Waiting for payment...',
                  style: TextStyle(color: Colors.black.withValues(alpha: .6))),
            ],
          ),
        ];
    }
  }
}
