import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app.dart';
import '../../services/local_server_service.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/kiosk_shell.dart';
import 'tap_to_start_screen.dart';

class DigitalCopyScreen extends StatefulWidget {
  const DigitalCopyScreen({super.key});

  @override
  State<DigitalCopyScreen> createState() => _DigitalCopyScreenState();
}

class _DigitalCopyScreenState extends State<DigitalCopyScreen> {
  LocalShare? _share;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startServer());
  }

  Future<void> _startServer() async {
    setState(() => _loading = true);
    final app = AppScope.of(context, listen: false);
    final session = app.session!;
    final share = await app.localServerService.serve(
      sessionId: session.id,
      imageBytes: session.flattenedImage!,
    );
    if (mounted) {
      setState(() {
        _share = share;
        _loading = false;
      });
    }
  }

  Future<void> _done() async {
    final app = AppScope.of(context, listen: false);
    await app.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const TapToStartScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: KioskShell(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: _loading
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text('Preparing your digital copy…'),
                        ],
                      )
                    : _share == null
                        ? _NoNetwork(onRetry: _startServer, onDone: _done)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Take it with you', style: Theme.of(context).textTheme.headlineMedium),
                              const SizedBox(height: 8),
                              const Text(
                                'Connect your phone to the same SkyeLoop or café Wi‑Fi, then scan this code.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 22),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: SkyeColors.blue, width: 3),
                                ),
                                child: QrImageView(
                                  data: _share!.url,
                                  version: QrVersions.auto,
                                  size: 285,
                                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: SkyeColors.blue),
                                  dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square, color: SkyeColors.ink),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(_share!.url, textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: SkyeColors.blue)),
                              const SizedBox(height: 12),
                              const Text('The photo stays available until Done is tapped. No internet or cloud is used.',
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 24),
                              FilledButton.icon(onPressed: _done,
                                  icon: const Icon(Icons.done_all), label: const Text('Done')),
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

class _NoNetwork extends StatelessWidget {
  const _NoNetwork({required this.onRetry, required this.onDone});
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 92, color: SkyeColors.ink),
        const SizedBox(height: 20),
        Text('No local Wi‑Fi connection', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text(
          'Printing still works without Wi‑Fi. For a digital copy, connect the tablet to the venue router or turn on its configured hotspot, then retry.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          children: [
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry network')),
            TextButton(onPressed: onDone, child: const Text('Finish without digital copy')),
          ],
        ),
      ],
    );
  }
}

