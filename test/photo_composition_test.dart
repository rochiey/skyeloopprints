import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyeloop/models/photo_session.dart';
import 'package:skyeloop/models/pricing_tier.dart';
import 'package:skyeloop/widgets/photo_composition.dart';

void main() {
  // Renders the composition exactly like the preview screen does (FittedBox +
  // bounded preview area) and checks that no layout overflows occur and that
  // the strip tier stacks three 16:9 photo cells.
  testWidgets('strip composition stacks three 16:9 photos without overflow', (tester) async {
    tester.view.physicalSize = const Size(800, 1340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = PhotoSession(tier: PricingTier.strip);
    session.photoPaths.addAll(['missing_1.jpg', 'missing_2.jpg', 'missing_3.jpg']);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470, maxHeight: 600),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PhotoComposition(session: session, onChanged: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    final cells = tester
        .widgetList<AspectRatio>(find.byType(AspectRatio))
        .where((cell) => cell.aspectRatio == 4 / 3)
        .toList();
    expect(cells, hasLength(3));
    expect(find.text('SKYE LOOP VENDO'), findsOneWidget);
    expect(find.text('SkyeLoop'), findsOneWidget);
  });

  testWidgets('single composition renders without overflow', (tester) async {
    tester.view.physicalSize = const Size(800, 1340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = PhotoSession(tier: PricingTier.single);
    session.photoPaths.add('missing_1.jpg');

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470, maxHeight: 600),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PhotoComposition(session: session, onChanged: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('SKYE LOOP VENDO'), findsOneWidget);
    expect(find.text('SkyeLoop'), findsOneWidget);
  });
}
