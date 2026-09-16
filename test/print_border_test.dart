import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyeloop/app.dart';
import 'package:skyeloop/models/photo_session.dart';
import 'package:skyeloop/models/pricing_tier.dart';
import 'package:skyeloop/models/print_border.dart';
import 'package:skyeloop/screens/production/preview_edit_screen.dart';
import 'package:skyeloop/state/app_controller.dart';
import 'package:skyeloop/theme/skyeloop_theme.dart';
import 'package:skyeloop/widgets/photo_composition.dart';
import 'package:skyeloop/widgets/print_border_frame.dart';

void main() {
  // Each frame is rendered through the same bounded preview harness the editor
  // uses, so a painter that overflows, or an inset that eats the strip's few
  // pixels of slack, fails here instead of on a customer's print.
  for (final tier in PricingTier.values) {
    for (final spec in bordersForLayout(tier.layout)) {
      testWidgets('${tier.name} + ${spec.label} renders without overflow', (tester) async {
        tester.view.physicalSize = const Size(800, 1340);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final session = PhotoSession(tier: tier);
        session.photoPaths.addAll(
          List<String>.generate(tier.shotCount, (index) => 'missing_$index.jpg'),
        );
        session.border = spec.id;

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
        // A plain photo draws no frame at all, so today's output is untouched.
        expect(
          find.byType(PrintBorderFrame),
          spec.id == PrintBorderId.none ? findsNothing : findsOneWidget,
        );
      });
    }
  }

  testWidgets('a frame from another layout falls back to a plain photo', (tester) async {
    tester.view.physicalSize = const Size(800, 1340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = PhotoSession(tier: PricingTier.single);
    session.photoPaths.add('missing_0.jpg');
    // A strip-only rail must never be drawn around a single portrait.
    session.border = PrintBorderId.filmStrip;

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
    expect(find.byType(PrintBorderFrame), findsNothing);
  });

  test('each layout offers No frame first and shares only that frame', () {
    final seen = <PrintBorderId>{};
    for (final tier in PricingTier.values) {
      final borders = bordersForLayout(tier.layout);
      expect(borders.first.id, PrintBorderId.none);
      final ids = borders.map((border) => border.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate frame in ${tier.name}');
      for (final border in borders) {
        expect(border.label, isNotEmpty);
        expect(border.blurb, isNotEmpty);
        if (border.id != PrintBorderId.none) {
          expect(seen.add(border.id), isTrue, reason: '${border.label} is shared across layouts');
        }
      }
    }
    // 23 designed frames, each offered for exactly one layout.
    expect(seen, hasLength(PrintBorderId.values.length - 1));
    expect(bordersForLayout(LayoutType.single), hasLength(9));
    expect(bordersForLayout(LayoutType.strip), hasLength(8));
    expect(bordersForLayout(LayoutType.grid), hasLength(9));
  });

  test('every frame id resolves, and layout fits are checked', () {
    for (final id in PrintBorderId.values) {
      expect(borderById(id), isNotNull, reason: '${id.name} is missing from the catalogue');
    }
    expect(borderById(PrintBorderId.none)!.inset, EdgeInsets.zero);
    expect(borderFitsLayout(PrintBorderId.none, LayoutType.grid), isTrue);
    expect(borderFitsLayout(PrintBorderId.filmStrip, LayoutType.strip), isTrue);
    expect(borderFitsLayout(PrintBorderId.filmStrip, LayoutType.grid), isFalse);
    expect(borderFitsLayout(PrintBorderId.comicGrid, LayoutType.grid), isTrue);
    expect(borderFitsLayout(PrintBorderId.comicGrid, LayoutType.single), isFalse);
  });

  testWidgets('the editor Border sheet offers grid frames and applies one', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController();
    final session = PhotoSession(tier: PricingTier.grid);
    session.photoPaths.addAll(List<String>.generate(4, (index) => 'missing_$index.jpg'));
    controller.session = session;

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: buildSkyeLoopTheme(),
          home: const PreviewEditScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(session.border, PrintBorderId.none);
    expect(find.byType(PrintBorderFrame), findsNothing);

    await tester.tap(find.text('Border'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a frame'), findsOneWidget);
    // A grid frame plus the plain option are offered, and no frame from
    // another layout leaks in (the full catalogue is covered above; the sheet
    // builds lazily, so only the first rows are on screen here).
    expect(find.text('No frame'), findsOneWidget);
    expect(find.text('Comic panels'), findsOneWidget);
    expect(find.text('Film strip'), findsNothing);
    expect(find.text('Wanted poster'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Comic panels'));
    await tester.pumpAndSettle();

    expect(session.border, PrintBorderId.comicGrid);
    expect(tester.takeException(), isNull);
    // The composition now draws the frame that was picked.
    expect(find.byType(PrintBorderFrame), findsOneWidget);
  });

  testWidgets('the portrait editor also offers the Border button', (tester) async {
    // The kiosk tablet runs the narrow (portrait) layout, which has its own
    // button row. The Border button was only wired into the wide column, so
    // portrait users could never reach the frame picker.
    tester.view.physicalSize = const Size(560, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController();
    final session = PhotoSession(tier: PricingTier.strip);
    session.photoPaths.addAll(List<String>.generate(3, (index) => 'missing_$index.jpg'));
    controller.session = session;

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: buildSkyeLoopTheme(),
          home: const PreviewEditScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Border'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a frame'), findsOneWidget);
    await tester.tap(find.text('Film strip'));
    await tester.pumpAndSettle();

    expect(session.border, PrintBorderId.filmStrip);
    expect(find.byType(PrintBorderFrame), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}