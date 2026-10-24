import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:skyeloop/services/preprint_band_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The band is laid out with the app's own font, so the tests load it too:
  // the fitted size, and every margin that follows from it, depend on it.
  setUpAll(() async {
    final loader = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'));
    await loader.load();
  });

  const bands = PreprintBandRenderer();

  // The band goes to the printer untouched, so its size is not cosmetic: the
  // height is the distance between the printhead and the cutter, and the width
  // is the printer's 576-dot line.
  test('the header band is print-sized', () async {
    final bytes = await bands.headerBand(venueName: 'The Mono Strip');
    expect(bytes, isNotEmpty);
    expect(
      _pngSize(bytes),
      (PreprintBandRenderer.printDotsWide, PreprintBandRenderer.gapDots),
    );
  });

  test('a blank venue name still renders a full band', () async {
    final bytes = await bands.headerBand(venueName: '   ');
    expect(
      _pngSize(bytes),
      (PreprintBandRenderer.printDotsWide, PreprintBandRenderer.gapDots),
    );
  });

  test('a very long venue name does not overflow the band', () async {
    final bytes = await bands.headerBand(
      venueName: 'The Extremely Long Riverside Coffee And Photobooth Company',
    );
    expect(
      _pngSize(bytes),
      (PreprintBandRenderer.printDotsWide, PreprintBandRenderer.gapDots),
    );
  });

  // The maintenance slip is real content, so it must stay well short of the
  // band it is followed by.
  test('the maintenance slip is a short strip', () async {
    final bytes = await bands.maintenanceSlip(
      venueName: 'The Mono Strip',
      printerLabel: 'Vozy G80',
      at: DateTime(2026, 8, 22, 16, 7),
    );
    final size = _pngSize(bytes);
    expect(size.$1, PreprintBandRenderer.printDotsWide);
    expect(size.$2, lessThan(PreprintBandRenderer.gapDots));
  });

  // The band is deliberately bare: the cafe name and nothing else. A rule or a
  // banner would add ink rows that are one more thing to keep aligned with the
  // cut, so a single line of text must be the only ink on the band.
  test('the header band prints the name and nothing else', () async {
    final groups = _inkRowGroups(await bands.headerBand(venueName: 'The Mono Strip'));
    expect(groups, hasLength(1), reason: 'only the masthead should carry ink');
  });

  // The band's margins are balanced against the strip's own geometry: the rows
  // above the name, the name, and the rows below it down to the first photo.
  test('the masthead margins are balanced with the photo under it', () {
    const band = 320.0;
    const name = 40.0;
    final equal = PreprintBandRenderer.mastheadTop(
      bandHeight: band,
      nameHeight: name,
      marginRatio: 1,
    );
    // Equal margins once the composition's own top padding is counted.
    expect(
      equal + name + equal,
      closeTo(band + PreprintBandRenderer.photoTopPadding, 0.001),
    );
    // The default keeps only a hair more air above the name.
    final biased = PreprintBandRenderer.mastheadTop(
      bandHeight: band,
      nameHeight: name,
    );
    expect(biased, greaterThan(equal));
    expect(biased - equal, lessThan(12));
  });

  // The drawn band has to agree with that maths.
  test('the masthead lands in the middle of the band, not low', () async {
    final groups = _inkRowGroups(await bands.headerBand(venueName: 'The Mono Strip'));
    final top = groups.single.$1;
    final bottom = PreprintBandRenderer.gapDots -
        groups.single.$2 +
        PreprintBandRenderer.photoTopPadding;
    expect((top - bottom).abs(), lessThan(48));
    expect(top, greaterThan(PreprintBandRenderer.gapDots ~/ 4));
  });

  // A long cafe name must SHRINK to fit rather than being cut off with an
  // ellipsis: nothing printed on the band can be corrected afterwards.
  test('a long venue name shrinks to the largest size that still fits', () {
    const label = 'THE MONO STRIP';
    final size = PreprintBandRenderer.headerFontSize(label);
    expect(size, greaterThanOrEqualTo(PreprintBandRenderer.minimumHeaderFontSize));
    expect(
      PreprintBandRenderer.measureHeader(label, size),
      lessThanOrEqualTo(PreprintBandRenderer.headerMaxWidth.toDouble()),
    );
    expect(
      PreprintBandRenderer.measureHeader(label, size + 2),
      greaterThan(PreprintBandRenderer.headerMaxWidth.toDouble()),
    );
  });

  // The client's own name. It used to be ellipsized on the strip, which is why
  // the cafe shortened it; it must now print whole, still on the single line the
  // band was designed around.
  test('a long cafe name the band can still fit prints whole on one line', () {
    final layout = PreprintBandRenderer.masthead('The Weekend Gathering');
    expect(layout.lines, hasLength(1));
    expect(layout.text, 'THE WEEKEND GATHERING');
    expect(layout.text, isNot(contains('...')));
    expect(layout.fontSize, greaterThanOrEqualTo(PreprintBandRenderer.minimumSingleLineFontSize));
    expect(layout.widestLine, lessThanOrEqualTo(PreprintBandRenderer.headerMaxWidth.toDouble()));
  });

  // A name that would have to be printed tiny on one line is word-wrapped
  // instead. Nothing printed on the band can be corrected afterwards, so the
  // name is never cut off: every word survives, on a line that fits the paper.
  test('a name too long for one line is wrapped, never cut off', () async {
    const name = 'The Extremely Long Riverside Coffee And Photobooth Company';
    final layout = PreprintBandRenderer.masthead(name);
    expect(layout.lines.length, greaterThan(1));
    expect(layout.lines.length, lessThanOrEqualTo(PreprintBandRenderer.headerMaxLines));
    expect(layout.text, PreprintBandRenderer.venueLabel(name));
    expect(layout.fontSize, greaterThan(PreprintBandRenderer.minimumHeaderFontSize));
    expect(
      layout.height,
      lessThanOrEqualTo(
        PreprintBandRenderer.gapDots - 2 * PreprintBandRenderer.minimumBandMargin,
      ),
    );
    for (final line in layout.lines) {
      expect(line.contains('...'), isFalse);
      expect(line.trim(), isNotEmpty);
      expect(
        PreprintBandRenderer.measureHeader(line, layout.fontSize),
        lessThanOrEqualTo(PreprintBandRenderer.headerMaxWidth.toDouble()),
      );
    }
    // Drawn: one ink block per line, and the block sits in the middle of the
    // band rather than against either edge.
    final groups = _inkRowGroups(await bands.headerBand(venueName: name));
    expect(groups, hasLength(layout.lines.length));
    final above = groups.first.$1;
    final below = PreprintBandRenderer.gapDots -
        groups.last.$2 +
        PreprintBandRenderer.photoTopPadding;
    expect((above - below).abs(), lessThan(48));
    expect(above, greaterThan(PreprintBandRenderer.minimumBandMargin));
    expect(below, greaterThan(0));
  });

  // One unbreakable word cannot be wrapped, so it is shrunk to the paper. It is
  // still not ellipsized or clipped.
  test('an unbreakable long name is shrunk, never ellipsized', () {
    final layout = PreprintBandRenderer.masthead('Supercalifragilisticexpialidocious');
    expect(layout.lines, hasLength(1));
    expect(layout.text, 'SUPERCALIFRAGILISTICEXPIALIDOCIOUS');
    expect(layout.text, isNot(contains('...')));
    expect(layout.widestLine, lessThanOrEqualTo(PreprintBandRenderer.headerMaxWidth.toDouble()));
  });

  test('the venue label is trimmed, upper-cased and never empty', () {
    expect(PreprintBandRenderer.venueLabel('  the mono strip '), 'THE MONO STRIP');
    expect(PreprintBandRenderer.venueLabel(''), 'SKYE LOOP');
  });
}

/// The row ranges that carry ink in a rendered band, top to bottom. A rule, a
/// banner or a second line of text each add their own group.
List<(int, int)> _inkRowGroups(Uint8List png) {
  final decoded = img.decodePng(png)!;
  final groups = <(int, int)>[];
  int? start;
  for (var y = 0; y < decoded.height; y++) {
    var inked = false;
    for (var x = 0; x < decoded.width; x++) {
      if (decoded.getPixel(x, y).r < 128) {
        inked = true;
        break;
      }
    }
    if (inked) {
      start ??= y;
    } else if (start != null) {
      groups.add((start, y - 1));
      start = null;
    }
  }
  if (start != null) groups.add((start, decoded.height - 1));
  return groups;
}

/// Reads the IHDR width and height out of a PNG.
(int, int) _pngSize(Uint8List bytes) {
  expect(String.fromCharCodes(bytes.sublist(1, 4)), 'PNG');
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}
