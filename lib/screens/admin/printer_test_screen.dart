import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../../app.dart';
import '../../theme/skyeloop_theme.dart';

/// Human-readable name for a print darkness adjustment (-5 lightest .. 5
/// darkest, 0 = the pipeline's built-in default output). Defined here and
/// shared with the admin dashboard so both show identical labels.
String printDarknessLabel(int darkness) {
  if (darkness == 0) return 'Default';
  return darkness > 0 ? 'Darker +$darkness' : 'Lighter ${-darkness}';
}

/// Full-screen camera test opened from the admin dashboard's print output
/// darkness card. The admin takes a photo and it is sent straight to the
/// configured Bluetooth printer (1 copy) so the current light/dark setting
/// can be judged on real paper. A permanent instruction explains how to
/// prepare the printer when it is not connected yet.
class PrinterTestScreen extends StatefulWidget {
  const PrinterTestScreen({super.key, required this.darkness});

  /// The darkness adjustment the test print should use.
  final int darkness;

  @override
  State<PrinterTestScreen> createState() => _PrinterTestScreenState();
}

enum _TestState { capture, printing, complete, failed }

class _PrinterTestScreenState extends State<PrinterTestScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _initializing = true;
  bool _capturing = false;
  String? _cameraError;
  _TestState _state = _TestState.capture;
  String? _error;

  /// The processed photo of the most recent capture, kept so a failed print
  /// can be retried without taking the photo again.
  Uint8List? _lastPrintBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      camera.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _cameraError = null;
    });
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _cameraError = 'Camera permission is needed to take a test photo.';
        });
      }
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('no-camera', 'No camera was found.');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initializing = false;
      });
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _cameraError = error.description ?? 'The camera could not be started.';
        });
      }
    }
  }

  /// The printer's printable line width in dots (80 mm paper at 203 DPI).
  /// The test photo is downscaled to this in Dart before sending so the
  /// Bluetooth transfer stays fast; the kiosk pipeline lays every image out
  /// at the same width (see PhotoComposition._printWidth).
  static const int _printWidth = 576;

  Future<Uint8List> _preparePrintImage(String path) async {
    final raw = await File(path).readAsBytes();
    final decoded = img.decodeJpg(raw);
    if (decoded == null) {
      throw const FormatException('The test photo could not be processed.');
    }
    final resized = decoded.width > _printWidth
        ? img.copyResize(decoded, width: _printWidth)
        : decoded;
    return Uint8List.fromList(img.encodePng(resized));
  }

  Future<void> _takeTestPhoto() async {
    final camera = _camera;
    if (_capturing ||
        _state != _TestState.capture ||
        camera == null ||
        !camera.value.isInitialized) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final photo = await camera.takePicture();
      final bytes = await _preparePrintImage(photo.path);
      try {
        File(photo.path).deleteSync();
      } catch (_) {
        // Best effort: the cache directory cleans itself up.
      }
      _lastPrintBytes = bytes;
      if (!mounted) return;
      setState(() {
        _state = _TestState.printing;
        _error = null;
      });
      await _printBytes(bytes);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _state = _TestState.failed;
          _error = error.description ?? 'The photo could not be captured.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _state = _TestState.failed;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _printBytes(Uint8List bytes) async {
    final app = AppScope.of(context, listen: false);
    await app.printerService.printImage(
      pngBytes: bytes,
      copies: 1,
      printerAddress: app.config.printerAddress,
      darkness: widget.darkness,
    );
    if (!mounted) return;
    setState(() => _state = _TestState.complete);
  }

  Future<void> _retryPrint() async {
    final bytes = _lastPrintBytes;
    if (bytes == null || _state == _TestState.printing) return;
    setState(() {
      _state = _TestState.printing;
      _error = null;
    });
    try {
      await _printBytes(bytes);
    } catch (error) {
      if (mounted) {
        setState(() {
          _state = _TestState.failed;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  void _backToCapture() {
    if (_state == _TestState.printing) return;
    setState(() {
      _state = _TestState.capture;
      _error = null;
      _lastPrintBytes = null;
    });
  }

  bool get _busy => _state == _TestState.printing;

  void _close() {
    if (_busy) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Never pop mid-send: the printer would be left waiting for raster data.
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test print'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: _busy ? null : _close,
              icon: const Icon(Icons.close),
              tooltip: 'Close test print',
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PrinterInstructions(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      _TestState.capture => _buildCapture(),
      _TestState.printing => const _TestStatus(
          key: ValueKey('printing'),
          icon: SizedBox(
              width: 90, height: 90,
              child: CircularProgressIndicator(strokeWidth: 7, color: SkyeColors.blue)),
          title: 'Sending the test photo…',
          message: 'Please wait — printing over Bluetooth can take a minute.',
        ),
      _TestState.complete => _TestStatus(
          key: const ValueKey('complete'),
          icon: const Icon(Icons.check_circle_rounded, size: 104, color: Color(0xFF2E7D32)),
          title: 'Test photo sent!',
          message: 'Check the printed photo. If it is too light or too dark, '
              'close this screen, adjust the darkness slider, and run another '
              'test. Current setting: ${printDarknessLabel(widget.darkness)}.',
          actions: [
            FilledButton.icon(
              onPressed: _backToCapture,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Take another'),
            ),
            TextButton(onPressed: _close, child: const Text('Done')),
          ],
        ),
      _TestState.failed => _TestStatus(
          key: const ValueKey('failed'),
          icon: const Icon(Icons.print_disabled_outlined, size: 100, color: Color(0xFFC62828)),
          title: 'Test print failed',
          message: _error ?? 'Check that the printer is powered on, paired, and has paper.',
          actions: [
            if (_lastPrintBytes != null)
              FilledButton.icon(
                onPressed: _retryPrint,
                icon: const Icon(Icons.refresh),
                label: const Text('Try printing again'),
              ),
            TextButton(onPressed: _backToCapture, child: const Text('Take another photo')),
          ],
        ),
    };
  }

  /// The live camera preview with the shutter used only for the test print.
  Widget _buildCapture() {
    final camera = _camera;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: ColoredBox(
                color: SkyeColors.ink,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (camera?.value.isInitialized ?? false)
                      CameraPreview(camera!)
                    else if (_initializing)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    else
                      _CameraUnavailable(
                        message: _cameraError,
                        onRetry: _initializeCamera,
                      ),
                    if (!_initializing && _cameraError == null)
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FloatingActionButton.large(
                            heroTag: 'test-print-shutter',
                            backgroundColor: Colors.white,
                            onPressed: _capturing ? null : _takeTestPhoto,
                            child: _capturing
                                ? const SizedBox(
                                    width: 34, height: 34,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3, color: SkyeColors.blue))
                                : const Icon(Icons.camera_alt_rounded,
                                    color: SkyeColors.blue, size: 34),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Take one photo — it prints right away so you can judge the '
              'lightness or darkness on paper.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SkyeColors.ink.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CHUNK-BREAK-4
}

/// Permanent instruction shown in every state of the test screen: the admin
/// must prepare the printer when it is not connected before the test is run.
class _PrinterInstructions extends StatelessWidget {
  const _PrinterInstructions();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SkyeColors.amber.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.print_outlined, color: Colors.brown),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Prepare the printer first if it is not connected: power it on, '
              'pair it in Android Settings → Bluetooth, make sure it is chosen '
              'under "80 mm Bluetooth printer" in Admin, and load paper before '
              'taking the test photo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.brown.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status layout shared by the printing / complete / failed states, mirroring
/// the kiosk printing screen.
class _TestStatus extends StatelessWidget {
  const _TestStatus({
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
    super.key,
  });

  final Widget icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(
                  spacing: 12, runSpacing: 10,
                  alignment: WrapAlignment.center, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// Camera preview fallback with a retry, matching the kiosk capture screen.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white, size: 64),
            const SizedBox(height: 14),
            Text(message ?? 'Camera unavailable', textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
