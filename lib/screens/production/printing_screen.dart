import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/kiosk_shell.dart';
import 'digital_copy_screen.dart';

enum _PrintState { printing, complete, failed }

class PrintingScreen extends StatefulWidget {
  const PrintingScreen({super.key});

  @override
  State<PrintingScreen> createState() => _PrintingScreenState();
}

class _PrintingScreenState extends State<PrintingScreen> {
  _PrintState _state = _PrintState.printing;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _print());
  }

  Future<void> _print() async {
    setState(() {
      _state = _PrintState.printing;
      _error = null;
    });
    final app = AppScope.of(context, listen: false);
    final session = app.session!;
    try {
      await app.printerService.printImage(
        pngBytes: session.flattenedImage!,
        copies: session.copies,
        printerAddress: app.config.printerAddress,
      );
      if (mounted) setState(() => _state = _PrintState.complete);
    } catch (error) {
      if (mounted) {
        setState(() {
          _state = _PrintState.failed;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  void _continue() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DigitalCopyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: KioskShell(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(42),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: switch (_state) {
                    _PrintState.printing => const _Status(
                        key: ValueKey('printing'),
                        icon: SizedBox(width: 90, height: 90,
                            child: CircularProgressIndicator(strokeWidth: 7, color: SkyeColors.blue)),
                        title: 'Printing your moment…',
                        message: 'Please wait and do not close the app.',
                      ),
                    _PrintState.complete => _Status(
                        key: const ValueKey('complete'),
                        icon: const Icon(Icons.check_circle_rounded, size: 104, color: Color(0xFF2E7D32)),
                        title: 'Your print is ready!',
                        message: 'Tear carefully at the perforation, then continue for your digital copy.',
                        actions: [FilledButton.icon(onPressed: _continue,
                            icon: const Icon(Icons.qr_code_rounded), label: const Text('Get digital copy'))],
                      ),
                    _PrintState.failed => _Status(
                        key: const ValueKey('failed'),
                        icon: const Icon(Icons.print_disabled_outlined, size: 100, color: Color(0xFFC62828)),
                        title: 'Printer needs attention',
                        message: _error ?? 'Check that the printer is powered on, paired, and has paper.',
                        actions: [
                          FilledButton.icon(onPressed: _print,
                              icon: const Icon(Icons.refresh), label: const Text('Try again')),
                          TextButton(onPressed: _continue, child: const Text('Continue without print')),
                        ],
                      ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.title, required this.message, this.actions = const [], super.key});
  final Widget icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 28),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 28),
          Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: actions),
        ],
      ],
    );
  }
}

