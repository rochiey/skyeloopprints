import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyeloop/app.dart';
import 'package:skyeloop/state/app_controller.dart';

void main() {
  testWidgets('start screen opens the three layout choices', (tester) async {
    tester.view.physicalSize = const Size(800, 1340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SkyeLoopApp(controller: AppController()));
    expect(find.text('Tap anywhere to start'), findsOneWidget);

    await tester.tap(find.text('Tap anywhere to start'));
    await tester.pumpAndSettle();

    expect(find.text('One perfect shot'), findsOneWidget);
    expect(find.text('Three-photo strip'), findsOneWidget);
    expect(find.text('Four-photo grid'), findsOneWidget);
  });
}

