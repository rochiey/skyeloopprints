import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skyeloop/app.dart';
import 'package:skyeloop/models/pricing_tier.dart';
import 'package:skyeloop/screens/production/capture_screen.dart';
import 'package:skyeloop/state/app_controller.dart';

/// The kiosk ships as an Android APK, but the flow is tested with
/// `flutter run -d windows`. Desktop has no camera plugin, and the capture
/// screen used to sit on its loading spinner forever because only
/// [CameraException] was handled. These tests lock in the desktop test-camera
/// behaviour so the rest of the flow (frames, printing, digital copy) stays
/// reachable on a PC.
void main() {
  testWidgets('desktop capture screen never hangs in the camera phase', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController()..beginSession(PricingTier.strip);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(controller: controller, child: const MaterialApp(home: CaptureScreen())),
    );
    await tester.pump();

    final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (desktop) {
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('TEST MODE'), findsOneWidget);
      expect(find.text('Windows test mode'), findsOneWidget);
    }

    // The shutter must be reachable so a session can be finished regardless of
    // whether a real camera is available.
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
