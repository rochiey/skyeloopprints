import 'package:flutter_test/flutter_test.dart';

import 'package:skyeloop/app.dart';
import 'package:skyeloop/state/app_controller.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(SkyeLoopApp(controller: controller));
    await tester.pump();

    // The initial screen should show the venue name or a tap prompt.
    expect(find.text('Tap anywhere to start'), findsWidgets);
  });
}
