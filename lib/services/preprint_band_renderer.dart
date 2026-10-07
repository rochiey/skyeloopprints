import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Renders the bands the printer pre-prints into the gap between its printhead
/// and its cutter.
///
/// The Vozy G80 cannot print the last [gapDots] dot rows of a job: they are
/// still between the printhead and the cutter when the strip is cut, so they
/// stay inside the printer and come back out as the TOP of the next strip.
/// Those rows used to be fed blank, which is the empty gap that appeared above
/// every print. The kiosk now prints the cafe name into them instead, so the
/// next strip arrives with its header already on it.
///
/// The band is rendered here (not by the composition) because it has to be
/// sent as its own image at the end of a job, long after the photo has left
/// the printhead.
class PreprintBandRenderer {
  const PreprintBandRenderer();

  /// Printable dot width of the Vozy G80 (80 mm paper at 203 DPI).
  static const int printDotsWide = 576;

  /// Dot rows between the printhead and the cutter: 320 rows = 40 mm at
  /// 8 dots/mm. This is the band every job feeds after its photo, and it is
  /// also the height of the pre-printed header. Tune it by measuring the blank
  /// strip that used to appear above a finished print (mm x 8).
  static const int gapDots = 320;

  /// Font sizes are in printer dots, so what is drawn here is exactly what the
  /// printer puts on paper (the band is already [printDotsWide] wide).
  ///
  /// The masthead is one line at this size; a name too wide for the paper is
  /// shrunk until it fits rather than being split or cut off.
  static const double headerBaseFontSize = 64;
  static const double _minFontSize = 24;

  /// Widest a masthead line may be, in printer dots.
  static const int headerMaxWidth = printDotsWide - 64;

  /// Smallest size the masthead shrinks to before the name is ellipsized.
  static const double minimumHeaderFontSize = _minFontSize;

  /// White space the composition prints above its first photo (the container
  /// padding in PhotoComposition). On paper it reads as part of the gap under
  /// the cafe name, so the band's margins are balanced against it.
  static const int photoTopPadding = 18;

  /// How the band's spare rows are split above and below the cafe name, as
  /// top : bottom. 1.0 gives equal margins; a heading normally wants a little
  /// more air above it than below, so this is nudged just off 1.0.
  static const double headerMarginRatio = 1.15;

  static const Color _paper = Color(0xFFFFFFFF);
  static const Color _ink = Color(0xFF000000);

  static const TextStyle _headerStyle = TextStyle(
    fontFamily: 'Poppins',
    color: _ink,
    fontSize: headerBaseFontSize,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
    height: 1.05,
  );
  static const TextStyle _maintenanceTitleStyle = TextStyle(
    fontFamily: 'Poppins',
    color: _ink,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.1,
  );
  static const TextStyle _maintenanceLineStyle = TextStyle(
    fontFamily: 'Poppins',
    color: _ink,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );
  static const TextStyle _maintenanceNoteStyle = TextStyle(
    fontFamily: 'Poppins',
    color: _ink,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// The cafe-name band that ends every job. It is not cut off with the current
  /// strip: it stays in the printhead-to-cutter gap and becomes the header of
  /// the next print.
  ///
  /// The band carries the name and nothing else - no rules, no box. The name is
  /// centred in the strip's head so the margins above and below it match (see
  /// [mastheadTop]); [marginRatio] overrides [headerMarginRatio] for previews.
  Future<Uint8List> headerBand({
    required String venueName,
    int dotsTall = gapDots,
    double marginRatio = headerMarginRatio,
  }) {
    final label = venueLabel(venueName);
    return _render(printDotsWide, dotsTall, (canvas, size) {
      final name = _fitText(label, _headerStyle, headerMaxWidth.toDouble());
      final nameTop = mastheadTop(
        bandHeight: size.height,
        nameHeight: name.height,
        marginRatio: marginRatio,
      );
      name.paint(canvas, Offset((size.width - name.width) / 2, nameTop));
    });
  }

  /// Where the masthead starts inside a band of [bandHeight] dot rows.
  ///
  /// The rows to divide are the band MINUS the name height PLUS
  /// [photoTopPadding], because that padding is white space the composition
  /// prints above its first photo and so counts as part of the gap below the
  /// name. [marginRatio] is top : bottom.
  static double mastheadTop({
    required double bandHeight,
    required double nameHeight,
    double marginRatio = headerMarginRatio,
  }) {
    final available = bandHeight + photoTopPadding - nameHeight;
    final top = available * marginRatio / (1 + marginRatio);
    return top.clamp(0.0, (bandHeight - nameHeight).clamp(0.0, bandHeight));
  }

  /// The maintenance slip printed before the first customer print (and whenever
  /// the admin loads a fresh roll). It loads the cafe-name band into the
  /// printer's gap and leaves a slip the operator can read, so no print is ever
  /// sent while the printer is still holding an empty header band.
  Future<Uint8List> maintenanceSlip({
    required String venueName,
    required String printerLabel,
    required DateTime at,
    int dotsTall = 230,
  }) {
    return _render(printDotsWide, dotsTall, (canvas, size) {
      final ink = Paint()..color = _ink;
      var y = 30.0;
      final title = _fitText('MAINTENANCE PRINT', _maintenanceTitleStyle, size.width - 56);
      title.paint(canvas, Offset((size.width - title.width) / 2, y));
      y += title.height + 20;
      canvas.drawRect(Rect.fromLTWH(48, y, size.width - 96, 3), ink);
      y += 18;
      final venue = _fitText(venueLabel(venueName), _maintenanceLineStyle, size.width - 56);
      venue.paint(canvas, Offset((size.width - venue.width) / 2, y));
      y += venue.height + 12;
      final details = _fitText('$printerLabel  |  ${_stamp(at)}', _maintenanceNoteStyle, size.width - 56);
      details.paint(canvas, Offset((size.width - details.width) / 2, y));
      y += details.height + 10;
      final note = _fitText('Cafe name loaded for the next print.', _maintenanceNoteStyle, size.width - 56);
      note.paint(canvas, Offset((size.width - note.width) / 2, y));
    });
  }

  /// The venue name as it is printed: trimmed, upper-cased and never empty.
  static String venueLabel(String venueName) {
    final trimmed = venueName.trim();
    return (trimmed.isEmpty ? 'Skye Loop' : trimmed).toUpperCase();
  }

  /// `2026-08-22 16:07` - kept dependency-free on purpose.
  static String _stamp(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }

  /// Font size the masthead uses for [venueName]: the largest size at or below
  /// the header style's own size that still keeps the whole name on one line.
  /// A long cafe name is shrunk to fit, never cut off.
  static double headerFontSize(String venueName) =>
      _fitFontSize(venueLabel(venueName), _headerStyle, headerMaxWidth.toDouble());

  /// Natural width of [value] as a masthead line at [fontSize], in printer dots.
  static double measureHeader(String value, double fontSize) =>
      _measure(value, _headerStyle.copyWith(fontSize: fontSize)).width;

  /// The largest size at or below [style]'s own size at which [value] still fits
  /// [maxWidth] on one line.
  static double _fitFontSize(String value, TextStyle style, double maxWidth) {
    final base = style.fontSize ?? headerBaseFontSize;
    var fontSize = base;
    while (fontSize > _minFontSize &&
        _measure(value, style.copyWith(fontSize: fontSize)).width > maxWidth) {
      fontSize = (fontSize - 2).clamp(_minFontSize, base);
    }
    return fontSize;
  }

  /// Lays [value] out on one line, shrunk to fit [maxWidth] and ellipsized only
  /// when even the smallest size is still too wide.
  static TextPainter _fitText(String value, TextStyle style, double maxWidth) {
    final fontSize = _fitFontSize(value, style, maxWidth);
    final natural = _measure(value, style.copyWith(fontSize: fontSize));
    if (natural.width <= maxWidth) return natural;
    return TextPainter(
      text: TextSpan(text: value, style: style.copyWith(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
  }

  /// Natural, unconstrained single-line layout of [value].
  static TextPainter _measure(String value, TextStyle style) => TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout();

  /// Paints a white band of exactly [width] x [height] device dots and encodes
  /// it as a PNG. The print pipeline scales whatever it is given to 576 dots
  /// wide, so rendering at print size keeps every stroke pixel-exact.
  static Future<Uint8List> _render(
    int width,
    int height,
    void Function(ui.Canvas canvas, Size size) paint,
  ) async {
    final size = Size(width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
    paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('The printer band could not be rendered.');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
