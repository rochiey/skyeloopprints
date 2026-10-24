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
  /// Short names print at this size on one line. A name that does not fit is
  /// first shrunk; if it would have to go below [minimumSingleLineFontSize] it
  /// is word-wrapped over up to [headerMaxLines] lines instead, so a long cafe
  /// name is always printed whole - never split mid-word, never ellipsized.
  static const double headerBaseFontSize = 64;
  static const double _minFontSize = 24;

  /// Widest a masthead line may be, in printer dots.
  static const int headerMaxWidth = printDotsWide - 64;

  /// Smallest one-line size the masthead aims for. A name that would have to
  /// go smaller is wrapped onto more lines instead of being printed tiny.
  static const double minimumHeaderFontSize = _minFontSize;

  /// Below this one-line size the masthead is word-wrapped instead of printed
  /// small. Names that still fit at or above it keep the single-line look the
  /// band was designed around. Set it to 0 to always keep one line, or to
  /// [headerBaseFontSize] to wrap every name that does not fit at full size.
  static const double minimumSingleLineFontSize = 32;

  /// Most lines the name may be wrapped over. The band is 40 mm tall, so a
  /// taller block would crowd the margins the design balances against.
  static const int headerMaxLines = 3;

  /// Blank that must stay above and below the wrapped block, in dot rows.
  static const int minimumBandMargin = 24;

  /// A wrapped layout is only taken when it buys at least this much font size
  /// over the layout before it (so a name wraps only when it really has to).
  static const double wrapFontSizeGain = 1.15;

  /// Absolute floor. Only one unbreakable word still wider than the paper at
  /// this size can reach it, and it is shrunk, never ellipsized.
  static const double _hardMinimumFontSize = 10;

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
    final layout = masthead(venueName);
    return _render(printDotsWide, dotsTall, (canvas, size) {
      final top = mastheadTop(
        bandHeight: size.height,
        nameHeight: layout.height,
        marginRatio: marginRatio,
      );
      final style = _headerStyle.copyWith(fontSize: layout.fontSize);
      for (var index = 0; index < layout.lines.length; index++) {
        final line = _paintable(layout.lines[index], style);
        line.paint(
          canvas,
          Offset((size.width - line.width) / 2, top + index * layout.lineHeight),
        );
      }
    });
  }

  /// The cafe name as the band prints it: [venueLabel] on one line when that is
  /// still worth printing, otherwise word-wrapped over at most [headerMaxLines]
  /// lines. The result is never wider than the paper and never ellipsized, so a
  /// long venue name cannot arrive on the strip cut off.
  static MastheadLayout masthead(String venueName) {
    final label = venueLabel(venueName);
    final single = _layout(
      [label],
      _fitFontSize(label, _headerStyle, headerMaxWidth.toDouble()),
    );
    // A name that still reads on one line keeps the single-line design.
    if (single.fontSize >= minimumSingleLineFontSize) return single;
    final words = label.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    var best = single;
    for (var count = 2; count <= headerMaxLines && count <= words.length; count++) {
      final candidate = _bestWrapped(words, count);
      if (candidate == null) continue;
      if (candidate.fontSize > best.fontSize * wrapFontSizeGain) best = candidate;
    }
    return best;
  }

  /// The best [lineCount]-line split of [words]: the one that allows the largest
  /// single font size for the whole block, preferring the most even split when
  /// two splits tie (that keeps the block looking like a heading, not a ragged
  /// paragraph). Returns null when the block cannot fit the band's height.
  static MastheadLayout? _bestWrapped(List<String> words, int lineCount) {
    final maxWidth = headerMaxWidth.toDouble();
    final maxBlock = gapDots - 2 * minimumBandMargin;
    MastheadLayout? best;
    void consider(List<String> lines) {
      var fontSize = _headerStyle.fontSize ?? headerBaseFontSize;
      for (final line in lines) {
        final fit = _fitFontSize(line, _headerStyle, maxWidth);
        if (fit < fontSize) fontSize = fit;
      }
      final candidate = _layout(lines, fontSize);
      if (candidate.height > maxBlock) return;
      if (best == null ||
          candidate.fontSize > best!.fontSize ||
          (candidate.fontSize == best!.fontSize && candidate.widestLine < best!.widestLine)) {
        best = candidate;
      }
    }

    void split(int from, int linesLeft, List<String> acc) {
      if (linesLeft == 1) {
        consider([...acc, words.sublist(from).join(' ')]);
        return;
      }
      for (var end = from + 1; end <= words.length - linesLeft + 1; end++) {
        acc.add(words.sublist(from, end).join(' '));
        split(end, linesLeft - 1, acc);
        acc.removeLast();
      }
    }

    split(0, lineCount, <String>[]);
    return best;
  }

  /// A block of [lines] at [fontSize], with the measurements the band needs.
  static MastheadLayout _layout(List<String> lines, double fontSize) {
    final style = _headerStyle.copyWith(fontSize: fontSize);
    var widest = 0.0;
    for (final line in lines) {
      final width = _measure(line, style).width;
      if (width > widest) widest = width;
    }
    return MastheadLayout(
      lines: List<String>.unmodifiable(lines),
      fontSize: fontSize,
      lineHeight: fontSize * (_headerStyle.height ?? 1.05),
      widestLine: widest,
    );
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

  /// Font size the masthead uses for [venueName] on ONE line: the largest size
  /// that still keeps the whole name on one line. This is the size short names
  /// are printed at; see [masthead] for the layout the band actually paints,
  /// which wraps a name that would have to be printed tiny on one line.
  static double headerFontSize(String venueName) =>
      _fitFontSize(venueLabel(venueName), _headerStyle, headerMaxWidth.toDouble());

  /// Natural width of [value] as a masthead line at [fontSize], in printer dots.
  static double measureHeader(String value, double fontSize) =>
      _measure(value, _headerStyle.copyWith(fontSize: fontSize)).width;

  /// The largest size at or below [style]'s own size at which [value] still fits
  /// [maxWidth] on one line.
  ///
  /// Measured by bisection rather than by stepping down: a long name is fitted
  /// many times while the wrapped layouts are compared, and the old descending
  /// loop stopped at [_minFontSize] without checking that the name still fitted
  /// at that size, which is how a long cafe name ended up ellipsized. The
  /// result here is the exact dot size that fits - one dot larger overflows.
  static double _fitFontSize(String value, TextStyle style, double maxWidth) {
    final base = style.fontSize ?? headerBaseFontSize;
    bool fits(double fontSize) =>
        _measure(value, style.copyWith(fontSize: fontSize)).width <= maxWidth;
    if (fits(base)) return base;
    var tooBig = base;
    var tooSmall = _hardMinimumFontSize;
    if (!fits(tooSmall)) return tooSmall;
    while (tooBig - tooSmall > 1) {
      final middle = ((tooBig + tooSmall) / 2).floorToDouble();
      if (fits(middle)) {
        tooSmall = middle;
      } else {
        tooBig = middle;
      }
    }
    return tooSmall;
  }

  /// Lays [value] out on one line, shrunk to fit [maxWidth] and ellipsized only
  /// when even the hard minimum size is still too wide (used by the maintenance
  /// slip, whose lines are short fixed strings).
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

  /// [value] laid out for painting on the band: its natural width when it fits,
  /// otherwise ellipsized against [headerMaxWidth]. Only a single unbreakable
  /// word wider than the paper at [_hardMinimumFontSize] can reach the ellipsis;
  /// a name with spaces is word-wrapped by [masthead] instead.
  static TextPainter _paintable(String value, TextStyle style) {
    final natural = _measure(value, style);
    if (natural.width <= headerMaxWidth) return natural;
    return TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: headerMaxWidth.toDouble());
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

/// A cafe name laid out for the pre-printed band: one or a few lines at a single
/// font size, measured in printer dots so what is drawn is what is printed.
class MastheadLayout {
  const MastheadLayout({
    required this.lines,
    required this.fontSize,
    required this.lineHeight,
    required this.widestLine,
  });

  /// The name, one entry per printed line. Words are never split between lines.
  final List<String> lines;

  /// Font size shared by every line, in printer dots.
  final double fontSize;

  /// Distance from one line's top to the next, in dot rows.
  final double lineHeight;

  /// Width of the widest line, in printer dots.
  final double widestLine;

  /// Total height of the block, in dot rows.
  double get height => lineHeight * lines.length;

  /// The whole name as one string, for tests and previews.
  String get text => lines.join(' ');
}
