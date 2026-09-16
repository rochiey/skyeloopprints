import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:skyeloop/widgets/brand_mark.dart';

/// The client uploads their own logo through Admin. It used to be cropped into
/// a circle with [BoxFit.cover], which threw away the edges of any logo that
/// was not square. It is now shown whole and scaled to fill the space it is
/// given, so a wide or tall logo stays readable and as large as possible.
void main() {
  late Directory tempDir;
  late String wideLogoPath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('brand_mark_test');
    // A 4:1 banner logo, the shape most venue logos have.
    final logo = img.Image(width: 400, height: 100);
    img.fill(logo, color: img.ColorRgb8(9, 84, 155));
    wideLogoPath = p.join(tempDir.path, 'logo.png');
    await File(wideLogoPath).writeAsBytes(img.encodePng(logo));
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('an uploaded logo is shown whole, never cropped to a circle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: BrandMark(
            imagePath: wideLogoPath,
            size: 200,
            maxWidth: 400,
            maxHeight: 600,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ClipOval), findsNothing);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);

    // The artwork may use the whole box it was given, not a [size] square.
    expect(tester.getSize(find.byType(BrandMark)), const Size(400, 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without maxWidth/maxHeight the box stays a size square', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: BrandMark(imagePath: wideLogoPath, size: 150)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(BrandMark)), const Size(150, 150));
  });

  testWidgets('a missing branding file falls back to the built-in mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: BrandMark(imagePath: 'no_such_logo.png', size: 120)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ClipOval), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
