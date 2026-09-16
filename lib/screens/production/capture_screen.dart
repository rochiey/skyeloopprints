import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../../app.dart';
import '../../models/photo_session.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/back_to_start_button.dart';
import '../../widgets/kiosk_shell.dart';
import '../../widgets/screen_heading.dart';
import 'preview_edit_screen.dart';

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

  /// When set, the next shot re-captures [int] (0-based) in place instead of
  /// appending a new one. Allows retaking a single shot without clearing all.
  int? _retakeIndex;

  /// True on desktop test runs (`flutter run -d windows`). Production always
  /// ships as the Android APK, where this is false, so the real permission
  /// prompt and tablet camera path stay exactly the same.
  bool get _isDesktopTestMode =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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
    if (_isDesktopTestMode) {
      // Desktop test runs have no camera plugin and no Android permission
      // system. Skip both so the screen shows its test-mode viewfinder
      // instead of loading forever. Never reached on the kiosk APK.
      setState(() {
        _initializing = false;
        _cameraError = null;
      });
      return;
    }
    setState(() {
      _initializing = true;
      _cameraError = null;
    });
    try {
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
    } catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _cameraError = _cameraErrorMessage(error);
        });
      }
    }
  }

  /// Turns any camera/plugin failure into a friendly message. Platforms with
  /// no camera implementation throw [UnimplementedError] or
  /// [MissingPluginException] instead of [CameraException]; catching only the
  /// latter left the viewfinder spinning forever.
  String _cameraErrorMessage(Object error) {
    if (error is CameraException) {
      return error.description ?? 'The camera could not be started.';
    }
    return 'The camera could not be started. Tap "Use test photo" to keep testing.';
  }

  Future<void> _takeNextPhoto() async {
    final app = AppScope.of(context, listen: false);
    final session = app.session!;
    if (_capturing ||
        (session.photoPaths.length >= session.tier.shotCount && _retakeIndex == null)) {
      return;
    }
    setState(() => _capturing = true);
    for (var number = 3; number >= 1; number--) {
      if (!mounted) return;
      setState(() => _countdown = number);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    try {
      final path = _isDesktopTestMode
          ? await _writeTestPhoto(session)
          : (await _camera!.takePicture()).path;
      _storePhoto(session, path);
      if (!mounted) return;
      setState(() {
        _countdown = null;
        _retakeIndex = null;
      });
    } on CameraException catch (error) {
      _captureFailed(error.description ?? 'The photo could not be captured. Please try again.');
    } catch (_) {
      _captureFailed('The photo could not be captured. Please try again.');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// Stops the countdown overlay and reports a capture failure, so a failed
  /// shot never leaves the screen counting down or stuck.
  void _captureFailed(String message) {
    if (mounted) setState(() => _countdown = null);
    _show(message);
  }

  /// Inserts [path] into the session, either replacing the actively retaken
  /// shot in place or appending a new shot at the end.
  void _storePhoto(PhotoSession session, String path) {
    final retakeIndex = _retakeIndex;
    if (retakeIndex != null && retakeIndex < session.photoPaths.length) {
      final previous = session.photoPaths[retakeIndex];
      if (previous != path) {
        try {
          File(previous).deleteSync();
        } catch (_) {
          // Best effort: leave the stale file behind if it cannot be removed.
        }
      }
      session.photoPaths[retakeIndex] = path;
    } else {
      session.photoPaths.add(path);
    }
  }

  /// Writes a generated image for the slot the next shot will fill (or the
  /// slot armed for a retake) and returns its path. Used by desktop test runs
  /// and by the "Use test photo" fallback when no camera is available.
  Future<String> _writeTestPhoto(PhotoSession session) async {
    final index = _retakeIndex ?? session.photoPaths.length;
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
    // Number the shot so testers can tell photos apart in the strip, the
    // frame picker and the print preview.
    img.drawString(
      canvas,
      '${index + 1}',
      font: img.arial48,
      x: 160,
      y: 210,
      color: img.ColorRgb8(30, 47, 82),
    );
    final directory = await AppScope.of(context, listen: false)
        .sessionFileService
        .sessionDirectory(session.id);
    final file = File(p.join(directory.path, 'mock_${index + 1}.jpg'));
    await file.writeAsBytes(img.encodeJpg(canvas, quality: 90));
    return file.path;
  }

  Future<void> _addMockPhoto() async {
    final session = AppScope.of(context, listen: false).session!;
    setState(() => _capturing = true);
    try {
      final path = await _writeTestPhoto(session);
      _storePhoto(session, path);
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _retakeIndex = null;
        });
      }
    }
  }

  void _proceedToPreview() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PreviewEditScreen()));
  }

  /// The live camera preview. The camera texture is sized to the sensor's
  /// true aspect ratio (previewSize is reported landscape, so swap it for the
  /// portrait kiosk) and cover-cropped into the viewfinder frame, so the
  /// image is never stretched before the shutter is pressed.
  Widget _cameraPreview() {
    final previewSize = _camera!.value.previewSize!;
    return Center(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(_camera!),
          ),
        ),
      ),
    );
  }

  void _retake() {
    final session = AppScope.of(context, listen: false).session!;
    session.photoPaths.clear();
    setState(() => _retakeIndex = null);
  }

  /// Arms the camera to re-capture [index] in place on the next shutter press.
  void _retakeShot(int index) {
    if (_capturing || index >= AppScope.of(context, listen: false).session!.photoPaths.length) return;
    setState(() => _retakeIndex = index);
  }

  /// Cancels an armed single-shot retake, returning to normal capture.
  void _cancelRetake() {
    setState(() => _retakeIndex = null);
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session!;
    final retaking = _retakeIndex != null;
    // All slots filled and not in the middle of a retake: the session is
    // complete and we only await the user's Proceed/retake action.
    final readyToProceed = !retaking && session.photoPaths.length >= session.tier.shotCount;
    return PopScope(
      canPop: false,
      child: KioskShell(
        header: ScreenHeading(
          title: readyToProceed
              ? 'Ready to continue'
              : retaking
                  ? 'Retake photo ${_retakeIndex! + 1} of ${session.tier.shotCount}'
                  : 'Photo ${min(session.photoPaths.length + 1, session.tier.shotCount)} of ${session.tier.shotCount}',
          subtitle: _isDesktopTestMode
              ? 'Test mode: each shutter press saves a numbered test photo.'
              : readyToProceed
                  ? 'Tap a photo to retake it, or Proceed to the next step.'
                  : retaking
                      ? 'Look at the camera. We will count down from three for this photo.'
                      : 'Look at the camera. We will count down from three.',
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const BackToStartButton(),
            if (readyToProceed)
              FilledButton.icon(
                onPressed: _capturing ? null : _proceedToPreview,
                icon: const Icon(Icons.done_all),
                label: const Text('Proceed'),
              )
            else ...[
              if (retaking)
                TextButton.icon(onPressed: _capturing ? null : _cancelRetake,
                    icon: const Icon(Icons.close), label: const Text('Cancel retake')),
              if (!retaking && session.photoPaths.isNotEmpty)
                TextButton.icon(onPressed: _capturing ? null : _retake,
                    icon: const Icon(Icons.refresh), label: const Text('Retake all')),
            ],
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final portrait = constraints.maxWidth < 600;
            if (portrait) {
              return Column(
                children: [
                  Expanded(
                    flex: 5,
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
                                if (_isDesktopTestMode)
                                  const _DesktopTestViewfinder()
                                else if (_camera?.value.isInitialized ?? false)
                                  _cameraPreview()
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
                                          style: const TextStyle(color: Colors.white, fontSize: 100,
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
                                        onPressed: _capturing || readyToProceed ? null : _takeNextPhoto,
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
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var index = 0; index < session.tier.shotCount; index++)
                          Padding(
                            padding: EdgeInsets.only(right: index != session.tier.shotCount - 1 ? 10 : 0),
                            child: SizedBox(
                              width: 100,
                              child: _ShotThumbnail(
                                index: index,
                                path: index < session.photoPaths.length
                                    ? session.photoPaths[index]
                                    : null,
                                retaking: _retakeIndex == index,
                                enabled: !_capturing,
                                onRetake: _retakeShot,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
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
                              if (_isDesktopTestMode)
                                const _DesktopTestViewfinder()
                              else if (_camera?.value.isInitialized ?? false)
                                _cameraPreview()
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
                                      onPressed: _capturing || readyToProceed ? null : _takeNextPhoto,
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
                        _ShotThumbnail(
                          index: index,
                          path: index < session.photoPaths.length
                              ? session.photoPaths[index]
                              : null,
                          retaking: _retakeIndex == index,
                          enabled: !_capturing,
                          onRetake: _retakeShot,
                        ),
                        if (index != session.tier.shotCount - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Viewfinder stand-in for desktop test runs (`flutter run -d windows`).
/// The kiosk ships on Android; this only exists so the rest of the flow can
/// be tested on a PC, which has no camera plugin.
class _DesktopTestViewfinder extends StatelessWidget {
  const _DesktopTestViewfinder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: SkyeColors.amber,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Text('TEST MODE',
                  style: TextStyle(
                      color: SkyeColors.ink, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 22),
            const Icon(Icons.photo_camera_back_outlined, color: Colors.white, size: 64),
            const SizedBox(height: 14),
            const Text('Windows test mode',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text(
              'No kiosk camera here. Every shutter press saves a numbered test photo, '
              'so you can test the frames, printing and digital copy flow.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
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

/// A single slot in the strip preview. Captured shots can be tapped to retake
/// that exact shot in place. [retaking] highlights the slot that is currently
/// armed to be re-captured on the next shutter press.
class _ShotThumbnail extends StatelessWidget {
  const _ShotThumbnail({
    required this.index,
    required this.path,
    required this.retaking,
    required this.enabled,
    required this.onRetake,
  });

  final int index;
  final String? path;
  final bool retaking;
  final bool enabled;
  final ValueChanged<int> onRetake;

  @override
  Widget build(BuildContext context) {
    final captured = path != null;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: retaking
                    ? SkyeColors.amber
                    : captured
                        ? SkyeColors.blue
                        : Colors.white,
                width: retaking ? 4 : 3,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: captured
                ? Image.file(File(path!), fit: BoxFit.cover)
                : Center(child: Text('${index + 1}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: SkyeColors.ink))),
          ),
          if (captured)
            Positioned(
              top: 6,
              right: 6,
              child: Tooltip(
                message: 'Retake photo ${index + 1}',
                child: Material(
                  color: retaking ? SkyeColors.amber : SkyeColors.blue,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: enabled ? () => onRetake(index) : null,
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.refresh, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

