import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../../app.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/back_to_start_button.dart';
import '../../widgets/kiosk_shell.dart';
import '../../widgets/screen_heading.dart';
import 'payment_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  bool _initializing = true;
  bool _capturing = false;
  String? _cameraError;
  int? _countdown;

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
          _cameraError = 'Camera permission is needed to take photos.';
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

  Future<void> _takeNextPhoto() async {
    final app = AppScope.of(context, listen: false);
    final session = app.session!;
    if (_capturing || session.photoPaths.length >= session.tier.shotCount) return;
    setState(() => _capturing = true);
    for (var number = 3; number >= 1; number--) {
      if (!mounted) return;
      setState(() => _countdown = number);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    try {
      final photo = await _camera!.takePicture();
      session.photoPaths.add(photo.path);
      if (!mounted) return;
      setState(() => _countdown = null);
      if (session.photoPaths.length == session.tier.shotCount) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PaymentScreen()),
        );
      }
    } on CameraException catch (error) {
      _show(error.description ?? 'The photo could not be captured. Please try again.');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _addMockPhoto() async {
    final app = AppScope.of(context, listen: false);
    final session = app.session!;
    setState(() => _capturing = true);
    final index = session.photoPaths.length;
    final canvas = img.Image(width: 360, height: 480);
    final palette = [
      const [232, 242, 248],
      const [248, 239, 229],
      const [244, 201, 193],
      const [255, 231, 168],
    ];
    final color = palette[index % palette.length];
    for (var y = 0; y < canvas.height; y++) {
      for (var x = 0; x < canvas.width; x++) {
        final shade = min(255, color[0] + (x * 16 ~/ canvas.width));
        canvas.setPixelRgb(x, y, shade, color[1], color[2]);
      }
    }
    final directory = await app.sessionFileService.sessionDirectory(session.id);
    final file = File(p.join(directory.path, 'mock_${index + 1}.jpg'));
    await file.writeAsBytes(img.encodeJpg(canvas, quality: 90));
    session.photoPaths.add(file.path);
    if (!mounted) return;
    setState(() => _capturing = false);
    if (session.photoPaths.length == session.tier.shotCount) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaymentScreen()));
    }
  }

  void _retake() {
    final session = AppScope.of(context, listen: false).session!;
    session.photoPaths.clear();
    setState(() {});
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session!;
    return PopScope(
      canPop: false,
      child: KioskShell(
        header: ScreenHeading(
          title: 'Photo ${min(session.photoPaths.length + 1, session.tier.shotCount)} of ${session.tier.shotCount}',
          subtitle: 'Look at the camera. We will count down from three.',
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const BackToStartButton(),
            if (session.photoPaths.isNotEmpty)
              TextButton.icon(onPressed: _capturing ? null : _retake,
                  icon: const Icon(Icons.refresh), label: const Text('Retake all')),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: ColoredBox(
                      color: SkyeColors.ink,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_camera?.value.isInitialized ?? false)
                            CameraPreview(_camera!)
                          else
                            _CameraUnavailable(
                              loading: _initializing,
                              message: _cameraError,
                              onRetry: _initializeCamera,
                              onMock: _capturing ? null : _addMockPhoto,
                            ),
                          if (_countdown != null)
                            ColoredBox(
                              color: const Color(0x44000000),
                              child: Center(
                                child: Text('$_countdown',
                                    style: const TextStyle(color: Colors.white, fontSize: 150,
                                        fontWeight: FontWeight.w900)),
                              ),
                            ),
                          if (!_initializing && _cameraError == null && _countdown == null)
                            Positioned(
                              bottom: 24,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: FloatingActionButton.large(
                                  heroTag: 'shutter',
                                  backgroundColor: Colors.white,
                                  onPressed: _capturing ? null : _takeNextPhoto,
                                  child: const Icon(Icons.camera_alt_rounded, color: SkyeColors.blue, size: 34),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < session.tier.shotCount; index++) ...[
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: index < session.photoPaths.length
                              ? SkyeColors.blue : Colors.white, width: 3),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: index < session.photoPaths.length
                            ? Image.file(File(session.photoPaths[index]), fit: BoxFit.cover)
                            : Center(child: Text('${index + 1}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                                    color: SkyeColors.ink))),
                      ),
                    ),
                    if (index != session.tier.shotCount - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({
    required this.loading,
    required this.message,
    required this.onRetry,
    required this.onMock,
  });

  final bool loading;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback? onMock;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: Colors.white));
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
            OutlinedButton(onPressed: onRetry,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white), child: const Text('Try again')),
            TextButton(onPressed: onMock,
                style: TextButton.styleFrom(foregroundColor: SkyeColors.amber), child: const Text('Use test photo')),
          ],
        ),
      ),
    );
  }
}

