import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/print_border.dart';

/// Draws [border] around [child] and reserves the ring the style needs.
///
/// The photos are inset by the style's [PrintBorder.inset], so the artwork
/// forms one piece that wraps every photo on the sheet. Everything is vector
/// art in solid black on white: no images, no grey tints, and no fills thinner
/// than the print pipeline's 1-bit halftone can hold.
class PrintBorderFrame extends StatelessWidget {
  const PrintBorderFrame({required this.border, required this.child, super.key});

  final PrintBorderId border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spec = borderById(border);
    if (border == PrintBorderId.none || spec == null) return child;
    final painter = _painterFor(border, spec.inset);
    // The same painter is handed to `painter` and `foregroundPainter` so an
    // overlay mark (washi tape, a passport stamp, a "POW!" burst) can sit on
    // top of the photos while the ring artwork stays under them. Every mark is
    // pure black on white, so painting the artwork twice cannot change the
    // printed result.
    return CustomPaint(
      painter: painter,
      foregroundPainter: painter,
      willChange: false,
      isComplex: false,
      child: Padding(
        padding: spec.inset,
        child: child,
      ),
    );
  }
}

CustomPainter _painterFor(PrintBorderId id, EdgeInsets inset) => switch (id) {
      PrintBorderId.wantedPoster => _WantedPosterPainter(inset),
      PrintBorderId.musicPlayer => _MusicPlayerPainter(inset),
      PrintBorderId.polaroid => _PolaroidPainter(inset),
      PrintBorderId.boardingPass => _BoardingPassPainter(inset),
      PrintBorderId.postageStamp => _PostageStampPainter(inset),
      PrintBorderId.magazineCover => _MagazineCoverPainter(inset),
      PrintBorderId.arcadeTv => _ArcadeScreenPainter(inset),
      PrintBorderId.passportStamp => _PassportStampPainter(inset),
      PrintBorderId.filmStrip => _FilmStripPainter(inset),
      PrintBorderId.filmRails => _FilmRailsPainter(inset),
      PrintBorderId.photoBoothStrip => _PhotoBoothStripPainter(inset),
      PrintBorderId.comicStrip => _ComicStripPainter(inset),
      PrintBorderId.polaroidStack => _PolaroidStackPainter(inset),
      PrintBorderId.receiptRoll => _ReceiptRollPainter(inset),
      PrintBorderId.stampSheet => _StampSheetPainter(inset),
      PrintBorderId.comicGrid => _ComicGridPainter(inset),
      PrintBorderId.contactSheet => _ContactSheetPainter(inset),
      PrintBorderId.photoBoothSheet => _PhotoBoothSheetPainter(inset),
      PrintBorderId.polaroidCollage => _PolaroidCollagePainter(inset),
      PrintBorderId.cctvWall => _CctvWallPainter(inset),
      PrintBorderId.yearbookPage => _YearbookPagePainter(inset),
      PrintBorderId.ticketQuartet => _TicketQuartetPainter(inset),
      PrintBorderId.stampBlock => _StampBlockPainter(inset),
      PrintBorderId.none => _PlainPainter(inset),
    };

// ---------------------------------------------------------------------------
// Print-safe palette. Only pure black ink and pure paper: the native pipeline
// lifts shadows with a gamma curve before Atkinson dithering, so any grey
// would turn into a spray of single dots instead of a solid mark.
// ---------------------------------------------------------------------------

const Color _ink = Color(0xFF000000);
const Color _paper = Color(0xFFFFFFFF);

Paint _stroke(double width) => Paint()
  ..color = _ink
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.butt
  ..strokeJoin = StrokeJoin.miter;

Paint _fill() => Paint()
  ..color = _ink
  ..style = PaintingStyle.fill;

Paint _paperFill() => Paint()
  ..color = _paper
  ..style = PaintingStyle.fill;

/// Base class for every frame painter.
abstract class _FramePainter extends CustomPainter {
  const _FramePainter(this.inset);

  final EdgeInsets inset;

  /// The window the photos occupy inside this frame's own box.
  Rect _window(Size size) => Rect.fromLTWH(
        inset.left,
        inset.top,
        size.width - inset.horizontal,
        size.height - inset.vertical,
      );

  /// The 2 x 2 grid cells, matching the gutters the composition lays out.
  List<Rect> _gridCells(Rect window) {
    final cellWidth = (window.width - kGridPhotoGutter) / 2;
    final cellHeight = (window.height - kGridPhotoGutter) / 2;
    return [
      Rect.fromLTWH(window.left, window.top, cellWidth, cellHeight),
      Rect.fromLTWH(window.left + cellWidth + kGridPhotoGutter, window.top, cellWidth, cellHeight),
      Rect.fromLTWH(window.left, window.top + cellHeight + kGridPhotoGutter, cellWidth, cellHeight),
      Rect.fromLTWH(
        window.left + cellWidth + kGridPhotoGutter,
        window.top + cellHeight + kGridPhotoGutter,
        cellWidth,
        cellHeight,
      ),
    ];
  }

  /// The three stacked strip cells, matching the composition's 4:3 ratios.
  List<Rect> _stripCells(Rect window) {
    final cellHeight = window.width / kStripPhotoAspect;
    return [
      for (var index = 0; index < 3; index++)
        Rect.fromLTWH(
          window.left,
          window.top + index * (cellHeight + kStripPhotoGutter),
          window.width,
          cellHeight,
        ),
    ];
  }

  /// The y of the centre of strip gutter [index] (0 or 1).
  double _stripGutterY(Rect window, int index) {
    final cellHeight = window.width / kStripPhotoAspect;
    return window.top + (index + 1) * cellHeight + index * kStripPhotoGutter + kStripPhotoGutter / 2;
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.inset != inset || oldDelegate.runtimeType != runtimeType;
}

/// Used only by `PrintBorderId.none`, which the frame widget short-circuits.
class _PlainPainter extends _FramePainter {
  const _PlainPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {}
}
// ---------------------------------------------------------------------------
// Shared drawing helpers. Stroke widths stay at 3 px or more and dashed marks
// at 6 px or more: a hairline is lifted to mid grey by the print tone curve and
// then dithered away into a broken dotted line.
// ---------------------------------------------------------------------------

TextPainter _layoutLabel(
  String text, {
  double size = 18,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 1.4,
  Color color = _ink,
}) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontFamily: 'Poppins',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

void _labelCentered(
  Canvas canvas,
  String text,
  Offset center, {
  double size = 18,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 1.4,
  Color color = _ink,
}) {
  final painter =
      _layoutLabel(text, size: size, weight: weight, letterSpacing: letterSpacing, color: color);
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

void _labelLeft(
  Canvas canvas,
  String text,
  Offset topLeft, {
  double size = 18,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 1.4,
  Color color = _ink,
}) {
  final painter =
      _layoutLabel(text, size: size, weight: weight, letterSpacing: letterSpacing, color: color);
  painter.paint(canvas, topLeft);
}

void _labelRight(
  Canvas canvas,
  String text,
  Offset topRight, {
  double size = 18,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 1.4,
  Color color = _ink,
}) {
  final painter =
      _layoutLabel(text, size: size, weight: weight, letterSpacing: letterSpacing, color: color);
  painter.paint(canvas, Offset(topRight.dx - painter.width, topRight.dy));
}

void _dashedLine(Canvas canvas, Offset from, Offset to,
    {double width = 2.5, double dash = 9, double gap = 6}) {
  final total = (to - from).distance;
  if (total <= 0) return;
  final direction = (to - from) / total;
  final paint = _stroke(width);
  var travelled = 0.0;
  while (travelled < total) {
    final end = math.min(travelled + dash, total);
    canvas.drawLine(from + direction * travelled, from + direction * end, paint);
    travelled = end + gap;
  }
}

void _dashedRect(Canvas canvas, Rect rect, {double width = 2.5, double dash = 9, double gap = 6}) {
  _dashedLine(canvas, rect.topLeft, rect.topRight, width: width, dash: dash, gap: gap);
  _dashedLine(canvas, rect.topRight, rect.bottomRight, width: width, dash: dash, gap: gap);
  _dashedLine(canvas, rect.bottomRight, rect.bottomLeft, width: width, dash: dash, gap: gap);
  _dashedLine(canvas, rect.bottomLeft, rect.topLeft, width: width, dash: dash, gap: gap);
}

/// Deterministic barcode bars (2-8 px bars, 2-6 px gaps) inside [rect].
void _barcode(Canvas canvas, Rect rect, {int seed = 11}) {
  if (rect.width < 12 || rect.height < 10) return;
  final paint = _fill();
  var value = (seed * 2654435761) & 0x7FFFFFFF;
  var x = rect.left;
  while (rect.right - x >= 4) {
    value = (value * 1103515245 + 12345) & 0x7FFFFFFF;
    final bar = 2.0 + (value % 4) * 2;
    final gap = 2.0 + ((value >> 5) % 3) * 2;
    final barWidth = math.min(bar, rect.right - x);
    canvas.drawRect(Rect.fromLTWH(x, rect.top, barWidth, rect.height), paint);
    x += barWidth + gap;
  }
}

/// Audio waveform bars spanning [rect], driven by a fixed pattern so the
/// printed artwork never changes between runs.
void _waveform(Canvas canvas, Rect rect) {
  final bars = math.max(8, (rect.width / 18).floor());
  final step = rect.width / bars;
  final paint = _fill();
  for (var index = 0; index < bars; index++) {
    final factor = 0.22 + 0.78 * (((index * 37) % 11) / 10);
    final height = rect.height * factor;
    final barWidth = math.min(5.0, step * 0.55);
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left + index * step + (step - barWidth) / 2,
        rect.bottom - height,
        barWidth,
        height,
      ),
      paint,
    );
  }
}
/// A film sprocket band: solid black with punched paper holes, or outlined.
void _sprocketBand(Canvas canvas, Rect band,
    {double holeWidth = 15, double holeHeight = 19, bool solid = true}) {
  if (band.width < 10 || band.height < holeHeight * 2) return;
  if (solid) canvas.drawRect(band, _fill());
  final holePaint = solid ? _paperFill() : _stroke(3);
  final radius = const Radius.circular(3);
  final step = holeHeight * 2.4;
  for (var y = band.top + 8; y + holeHeight <= band.bottom - 6; y += step) {
    final hole = Rect.fromCenter(
      center: Offset(band.center.dx, y + holeHeight / 2),
      width: holeWidth,
      height: holeHeight,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(hole, radius), holePaint);
  }
}

/// Postal perforation: a black band whose outer edge is bitten away by rows of
/// paper circles, which reads as a stamped edge at 203 dpi.
void _perforatedEdge(Canvas canvas, Rect rect, {double band = 9}) {
  canvas.drawRect(rect.deflate(band / 2), _stroke(band));
  final punch = _paperFill();
  const tooth = 9.0;
  for (var x = rect.left; x <= rect.right; x += tooth) {
    canvas.drawCircle(Offset(x, rect.top), band / 2, punch);
    canvas.drawCircle(Offset(x, rect.bottom), band / 2, punch);
  }
  for (var y = rect.top; y <= rect.bottom; y += tooth) {
    canvas.drawCircle(Offset(rect.left, y), band / 2, punch);
    canvas.drawCircle(Offset(rect.right, y), band / 2, punch);
  }
}

/// A torn receipt edge: a triangle wave running along [y].
void _zigzag(Canvas canvas, double y, double fromX, double toX,
    {double tooth = 10, double depth = 8, double width = 3}) {
  final path = Path()..moveTo(fromX, y);
  var up = true;
  var x = fromX;
  while (x < toX - 0.5) {
    x = math.min(x + tooth, toX);
    path.lineTo(x, up ? y - depth : y);
    up = !up;
  }
  canvas.drawPath(path, _stroke(width));
}

/// Punched paper circles across a gutter band, for tear-off perforations.
void _perforatedRule(Canvas canvas, Rect band) {
  canvas.drawRect(band, _fill());
  final punch = _paperFill();
  for (var x = band.left + 8; x <= band.right - 6; x += 16) {
    canvas.drawCircle(Offset(x, band.center.dy), 5, punch);
  }
}

/// A strip of washi tape, drawn over a photo corner.
void _tape(Canvas canvas, Offset center, double angle, {double width = 74, double height = 24}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angle);
  final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
  canvas.drawRect(rect, _paperFill());
  canvas.drawRect(rect, _stroke(3));
  final hatch = _stroke(3);
  for (var x = -width / 2 + 8; x < width / 2 - 4; x += 12) {
    canvas.drawLine(Offset(x, -height / 2 + 3), Offset(x, height / 2 - 3), hatch);
  }
  canvas.restore();
}

/// A comic-style action burst with an optional word punched out of it.
void _burst(Canvas canvas, Offset center, double radius, {String? word}) {
  const points = 13;
  final path = Path();
  for (var index = 0; index < points * 2; index++) {
    final r = index.isEven ? radius : radius * 0.58;
    final angle = -math.pi / 2 + index * math.pi / points;
    final point = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
    if (index == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  canvas.drawPath(path, _fill());
  final label = word;
  if (label != null) {
    _labelCentered(canvas, label, center, size: 17, letterSpacing: 1, color: _paper);
  }
}

void _star(Canvas canvas, Offset center, double radius) {
  const points = 5;
  final path = Path();
  for (var index = 0; index < points * 2; index++) {
    final r = index.isEven ? radius : radius * 0.45;
    final angle = -math.pi / 2 + index * math.pi / points;
    final point = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
    if (index == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  canvas.drawPath(path, _fill());
}

/// A small paper-airplane arrow, used by the travel frames.
void _plane(Canvas canvas, Offset center, double size) {
  final path = Path()
    ..moveTo(center.dx + size, center.dy)
    ..lineTo(center.dx - size, center.dy - size * 0.62)
    ..lineTo(center.dx - size * 0.3, center.dy)
    ..lineTo(center.dx - size, center.dy + size * 0.62)
    ..close();
  canvas.drawPath(path, _fill());
}

/// Registration corner marks pointing into [rect], offset [outset] px outward.
void _cropMarks(Canvas canvas, Rect rect, {double leg = 18, double outset = 7}) {
  final paint = _stroke(3);
  final left = rect.left - outset;
  final right = rect.right + outset;
  final top = rect.top - outset;
  final bottom = rect.bottom + outset;
  void corner(Offset point, double dx, double dy) {
    canvas.drawLine(point, point + Offset(dx * leg, 0), paint);
    canvas.drawLine(point, point + Offset(0, dy * leg), paint);
  }

  corner(Offset(left, top), 1, 1);
  corner(Offset(right, top), -1, 1);
  corner(Offset(left, bottom), 1, -1);
  corner(Offset(right, bottom), -1, -1);
}

/// A paper caption strip punched over the bottom of a photo, with a rule or
/// caption inside it. Used by the polaroid and yearbook frames.
void _captionStrip(Canvas canvas, Rect cell, String? caption, {double height = 28}) {
  final strip = Rect.fromLTWH(cell.left, cell.bottom - height, cell.width, height);
  canvas.drawRect(strip, _paperFill());
  canvas.drawLine(strip.topLeft, strip.topRight, _stroke(3));
  if (caption != null && caption.isNotEmpty) {
    _labelCentered(canvas, caption, strip.center, size: 16, letterSpacing: 2);
  } else {
    canvas.drawLine(
      Offset(strip.left + 12, strip.center.dy + 1),
      Offset(strip.right - 12, strip.center.dy + 1),
      _stroke(3),
    );
  }
}

/// The outer edge of a full-sheet frame: the box with a small page margin.
Rect _sheet(Size size, [double margin = 10]) =>
    Rect.fromLTRB(margin, margin, size.width - margin, size.height - margin);

// ---------------------------------------------------------------------------
// Single-photo frames.
// ---------------------------------------------------------------------------

/// A "wanted" bounty poster: heavy rules, a WANTED masthead and a bounty bar.
class _WantedPosterPainter extends _FramePainter {
  const _WantedPosterPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final sheet = _sheet(size);
    canvas.drawRect(sheet, _stroke(4));
    canvas.drawRect(sheet.deflate(5), _stroke(2.5));

    _labelCentered(canvas, 'WANTED', Offset(sheet.center.dx, 52),
        size: 54, weight: FontWeight.w800, letterSpacing: 8);
    canvas.drawLine(Offset(sheet.left + 6, 88), Offset(sheet.right - 6, 88), _stroke(3));

    final barY = window.bottom + 26;
    _star(canvas, Offset(sheet.left + 26, barY), 12);
    _star(canvas, Offset(sheet.right - 26, barY), 12);
    _labelCentered(canvas, 'DEAD OR ALIVE', Offset(sheet.center.dx, barY),
        size: 20, letterSpacing: 3);
    canvas.drawLine(Offset(sheet.left + 6, barY + 26), Offset(sheet.right - 6, barY + 26), _stroke(2.5));
    _labelCentered(canvas, 'REWARD  50,000,000', Offset(sheet.center.dx, barY + 52),
        size: 26, weight: FontWeight.w800, letterSpacing: 1.5);
  }
}

/// A streaming-app card: now-playing bar, waveform, progress bar and times.
class _MusicPlayerPainter extends _FramePainter {
  const _MusicPlayerPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final sheet = _sheet(size, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sheet, const Radius.circular(26)),
      _stroke(4),
    );

    final bar = Rect.fromLTRB(sheet.left + 10, sheet.top + 10, sheet.right - 10, window.top - 6);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(16)), _fill());
    final playCentre = Offset(bar.left + 30, bar.center.dy);
    canvas.drawPath(
      Path()
        ..moveTo(playCentre.dx - 7, playCentre.dy - 12)
        ..lineTo(playCentre.dx - 7, playCentre.dy + 12)
        ..lineTo(playCentre.dx + 12, playCentre.dy)
        ..close(),
      _paperFill(),
    );
    _labelLeft(canvas, 'NOW PLAYING', Offset(bar.left + 50, bar.center.dy - 11),
        size: 20, letterSpacing: 2.5, color: _paper);

    _waveform(canvas, Rect.fromLTRB(sheet.left + 16, window.bottom + 16, sheet.right - 16, window.bottom + 42));

    final trackY = window.bottom + 60;
    canvas.drawLine(Offset(sheet.left + 20, trackY), Offset(sheet.right - 20, trackY),
        _stroke(3)..color = _ink);
    final played = sheet.left + 20 + (sheet.width - 40) * 0.55;
    canvas.drawLine(Offset(sheet.left + 20, trackY), Offset(played, trackY), _stroke(8));
    canvas.drawCircle(Offset(played, trackY), 8, _fill());

    _labelLeft(canvas, '0:00', Offset(sheet.left + 20, trackY + 18), size: 16, letterSpacing: 1.5);
    _labelRight(canvas, '3:24', Offset(sheet.right - 20, trackY + 18), size: 16, letterSpacing: 1.5);
  }
}

/// An instant photo: thin rule hugging the picture and a wide caption chin.
class _PolaroidPainter extends _FramePainter {
  const _PolaroidPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final card = _sheet(size, 6);
    canvas.drawRect(card, _stroke(3));
    canvas.drawRect(window, _stroke(3));
    _labelCentered(canvas, '• instant memory •',
        Offset(card.center.dx, window.bottom + (card.bottom - window.bottom) / 2),
        size: 20, letterSpacing: 2);
  }
}

/// A boarding pass: masthead band, punched perforation and a barcode stub.
class _BoardingPassPainter extends _FramePainter {
  const _BoardingPassPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final sheet = _sheet(size, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(sheet, const Radius.circular(18)), _stroke(4));

    _plane(canvas, Offset(sheet.left + 34, 32), 13);
    _labelLeft(canvas, 'BOARDING PASS', Offset(sheet.left + 58, 22), size: 18, letterSpacing: 2.5);
    _labelRight(canvas, 'SKYE LOOP AIR', Offset(sheet.right - 10, 23), size: 17, letterSpacing: 1.5);

    final tear = window.bottom + 14;
    _dashedLine(canvas, Offset(sheet.left + 6, tear), Offset(sheet.right - 6, tear),
        width: 3, dash: 11, gap: 7);
    canvas.drawCircle(Offset(sheet.left + 6, tear), 10, _paperFill());
    canvas.drawCircle(Offset(sheet.right - 6, tear), 10, _paperFill());

    const labels = ['GATE', 'SEAT', 'CLASS'];
    const values = ['12', '4A', 'LOOP'];
    for (var index = 0; index < 3; index++) {
      final x = sheet.left + 54 + index * 200;
      _labelCentered(canvas, labels[index], Offset(x, tear + 22), size: 16, letterSpacing: 1.5);
      _labelCentered(canvas, values[index], Offset(x, tear + 44), size: 22,
          weight: FontWeight.w800, letterSpacing: 1);
    }
    _barcode(canvas, Rect.fromLTWH(sheet.left + 8, tear + 62, 240, 26));
    _labelRight(canvas, 'SL-2026', Offset(sheet.right - 10, tear + 66), size: 17, letterSpacing: 1.5);
  }
}

/// A postage stamp: perforated edge, inner rule and a value line.
class _PostageStampPainter extends _FramePainter {
  const _PostageStampPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    _perforatedEdge(canvas, Rect.fromLTRB(14, 14, size.width - 14, size.height - 14));
    canvas.drawRect(window, _stroke(3));
    final band = window.bottom + 18;
    _labelLeft(canvas, 'SKYELOOP', Offset(window.left, band), size: 17, letterSpacing: 2);
    _labelRight(canvas, 'POSTAGE 20', Offset(window.right, band), size: 17, letterSpacing: 2);
  }
}

/// A magazine cover: rules, a masthead and a cover-line band with a barcode.
class _MagazineCoverPainter extends _FramePainter {
  const _MagazineCoverPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final sheet = _sheet(size, 8);
    canvas.drawRect(sheet, _stroke(3));
    canvas.drawLine(Offset(sheet.left + 8, 14), Offset(sheet.right - 8, 14), _stroke(3));
    _labelCentered(canvas, 'SKYELOOP', Offset(sheet.center.dx, 50),
        size: 54, weight: FontWeight.w800, letterSpacing: 6);
    canvas.drawLine(Offset(sheet.left + 8, 84), Offset(sheet.right - 8, 84), _stroke(3));

    final band = window.bottom + 3;
    _labelLeft(canvas, 'ISSUE 04', Offset(window.left, band), size: 17, letterSpacing: 2);
    _labelRight(canvas, 'THE MOMENT ISSUE', Offset(window.right, band), size: 17, letterSpacing: 2);
    _barcode(canvas, Rect.fromLTWH(window.left, band + 26, 150, 20));
    _labelRight(canvas, 'SKYE LOOP VENDO', Offset(window.right, band + 27),
        size: 17, letterSpacing: 1.5);
  }
}

/// An arcade cabinet screen: chunky bezel, knobs and a player banner.
class _ArcadeScreenPainter extends _FramePainter {
  const _ArcadeScreenPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(_sheet(size), const Radius.circular(40)),
      _stroke(6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(_sheet(size, 22), const Radius.circular(28)),
      _stroke(3),
    );

    _labelLeft(canvas, 'PLAYER 1', Offset(window.left + 2, window.bottom + 9),
        size: 22, weight: FontWeight.w800, letterSpacing: 3);
    _labelLeft(canvas, 'INSERT COIN', Offset(window.left + 2, window.bottom + 41),
        size: 17, letterSpacing: 2);
    for (final x in [window.right - 54, window.right - 16]) {
      final centre = Offset(x, window.bottom + 29);
      canvas.drawCircle(centre, 13, _stroke(4));
      canvas.drawLine(centre, centre + const Offset(0, -9), _stroke(4));
    }
  }
}

/// A passport stamp card: thin frame plus an entry stamp over the corner.
class _PassportStampPainter extends _FramePainter {
  const _PassportStampPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    canvas.drawRect(_sheet(size), _stroke(3));

    final centre = Offset(window.right - 100, window.bottom - 100);
    canvas.drawCircle(centre, 88, _paperFill());
    canvas.drawCircle(centre, 86, _stroke(5));
    canvas.drawCircle(centre, 72, _stroke(3));
    _star(canvas, Offset(centre.dx, centre.dy - 57), 11);
    _labelCentered(canvas, 'ENTRY', Offset(centre.dx, centre.dy - 24),
        size: 26, weight: FontWeight.w800, letterSpacing: 3);
    canvas.drawLine(Offset(centre.dx - 56, centre.dy), Offset(centre.dx + 56, centre.dy), _stroke(3));
    _labelCentered(canvas, 'SKYELOOP', Offset(centre.dx, centre.dy + 21),
        size: 17, letterSpacing: 2.5);
    _labelCentered(canvas, 'APPROVED', Offset(centre.dx, centre.dy + 53),
        size: 18, letterSpacing: 3);
  }
}

// ---------------------------------------------------------------------------
// Three-photo strip frames. These take their room from the sides: the three
// 4:3 cells are rigid and the strip column only has a few pixels of slack, so
// a wide side rail is both the authentic film look and the layout-safe one.
// ---------------------------------------------------------------------------

/// A 35 mm film strip: solid sprocket rails with punched holes and edge codes.
class _FilmStripPainter extends _FramePainter {
  const _FilmStripPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _stripCells(window);
    _sprocketBand(canvas, Rect.fromLTWH(0, 0, 46, size.height), holeWidth: 15, holeHeight: 20);
    _sprocketBand(canvas, Rect.fromLTWH(size.width - 46, 0, 46, size.height),
        holeWidth: 15, holeHeight: 20);
    canvas.drawLine(const Offset(0, 6), Offset(size.width, 6), _stroke(3));
    canvas.drawLine(Offset(0, size.height - 6), Offset(size.width, size.height - 6), _stroke(3));
    for (var index = 0; index < cells.length; index++) {
      canvas.save();
      canvas.translate(23, cells[index].center.dy);
      canvas.rotate(-math.pi / 2);
      _labelCentered(canvas, '${index + 1}A', Offset.zero,
          size: 17, letterSpacing: 2, color: _paper);
      canvas.restore();
    }
  }
}

/// Light film rails: outlined rails, a tick sprocket and frame numbers.
class _FilmRailsPainter extends _FramePainter {
  const _FilmRailsPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _stripCells(window);
    final leftRail = Rect.fromLTRB(4, 4, 26, size.height - 4);
    final rightRail = Rect.fromLTRB(size.width - 26, 4, size.width - 4, size.height - 4);
    for (final rail in [leftRail, rightRail]) {
      canvas.drawRRect(RRect.fromRectAndRadius(rail, const Radius.circular(8)), _stroke(3));
    }
    final tick = _stroke(3);
    for (var y = leftRail.top + 14; y <= leftRail.bottom - 10; y += 26) {
      canvas.drawLine(Offset(leftRail.left + 3, y), Offset(leftRail.right - 3, y), tick);
    }
    for (var index = 0; index < 2; index++) {
      final y = _stripGutterY(window, index);
      _dashedLine(canvas, Offset(window.left, y), Offset(window.right, y),
          width: 3, dash: 12, gap: 8);
    }
    canvas.drawLine(Offset(window.left, 6), Offset(window.right, 6), _stroke(3));
    canvas.drawLine(
        Offset(window.left, size.height - 6), Offset(window.right, size.height - 6), _stroke(3));
    for (var index = 0; index < cells.length; index++) {
      _labelCentered(canvas, '${index + 1}', Offset(rightRail.center.dx, cells[index].center.dy),
          size: 18, letterSpacing: 1);
    }
  }
}

/// A photo booth strip: tear-off edges, dashed cut lines and crop marks.
class _PhotoBoothStripPainter extends _FramePainter {
  const _PhotoBoothStripPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _stripCells(window);
    _dashedLine(canvas, const Offset(0, 3), Offset(size.width, 3), width: 4, dash: 12, gap: 8);
    _dashedLine(canvas, Offset(0, size.height - 3), Offset(size.width, size.height - 3),
        width: 4, dash: 12, gap: 8);
    for (var index = 0; index < 2; index++) {
      final y = _stripGutterY(window, index);
      _dashedLine(canvas, Offset(window.left, y), Offset(window.right, y),
          width: 3, dash: 10, gap: 8);
    }
    for (final cell in cells) {
      _cropMarks(canvas, cell, leg: 14, outset: 4);
    }
    _labelCentered(canvas, 'SKYELOOP • 3-CUT', Offset(size.width / 2, size.height - 16),
        size: 17, letterSpacing: 2);
  }
}

/// A comic strip: inked panel gutters, panel numbers and a POW! burst.
class _ComicStripPainter extends _FramePainter {
  const _ComicStripPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _stripCells(window);
    canvas.drawRect(_sheet(size), _stroke(7));
    for (var index = 0; index < 2; index++) {
      final y = _stripGutterY(window, index);
      canvas.drawLine(Offset(_sheet(size).left, y), Offset(size.width - _sheet(size).left, y),
          _stroke(7));
    }
    for (var index = 0; index < cells.length; index++) {
      final tag = Rect.fromLTWH(cells[index].left + 6, cells[index].top + 6, 32, 32);
      canvas.drawRect(tag, _fill());
      _labelCentered(canvas, '${index + 1}', tag.center, size: 20, color: _paper);
    }
    _burst(canvas, Offset(cells.last.right - 48, cells.last.bottom - 48), 38, word: 'POW!');
  }
}

/// Three instant cards with captioned chins punched over the photo bottoms.
class _PolaroidStackPainter extends _FramePainter {
  const _PolaroidStackPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _stripCells(window);
    const captions = ['• ONE •', '• TWO •', '• THREE •'];
    for (var index = 0; index < cells.length; index++) {
      _captionStrip(canvas, cells[index], captions[index], height: 30);
    }
  }
}

/// A till receipt: torn zigzag edges, dashed sections and a barcode footer.
class _ReceiptRollPainter extends _FramePainter {
  const _ReceiptRollPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    _zigzag(canvas, 10, 12, size.width - 12);
    _zigzag(canvas, size.height - 8, 12, size.width - 12);
    _labelCentered(canvas, 'SKYELOOP RECEIPT', Offset(size.width / 2, 32),
        size: 17, letterSpacing: 2);
    for (var index = 0; index < 2; index++) {
      final y = _stripGutterY(window, index);
      _dashedLine(canvas, Offset(window.left, y), Offset(window.right, y),
          width: 3, dash: 10, gap: 7);
    }
    _barcode(canvas, Rect.fromLTWH(window.center.dx - 150, window.bottom + 4, 300, 20));
  }
}

/// A sheet of three perforated stamps with printed denominations.
class _StampSheetPainter extends _FramePainter {
  const _StampSheetPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _stripCells(window);
    _perforatedEdge(canvas, Rect.fromLTRB(16, 12, size.width - 16, size.height - 12));
    for (var index = 0; index < 2; index++) {
      final y = _stripGutterY(window, index);
      _perforatedRule(canvas, Rect.fromLTRB(window.left, y - 5, window.right, y + 5));
    }
    for (final cell in cells) {
      final box = Rect.fromLTWH(4, cell.center.dy - 16, 30, 32);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), _stroke(3));
      _labelCentered(canvas, '20', box.center, size: 16, letterSpacing: 1);
    }
  }
}

// ---------------------------------------------------------------------------
// Four-photo grid frames. A 2 x 2 sheet is already a grid, so these styles lean
// into shapes that are 2 x 2 by nature: a comic page, a contact sheet, a photo
// booth sheet and a monitor wall.
// ---------------------------------------------------------------------------

/// A four-panel comic page: inked rules, panel numbers and a POW! burst.
class _ComicGridPainter extends _FramePainter {
  const _ComicGridPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _gridCells(window);
    final sheet = _sheet(size);
    canvas.drawRect(sheet, _stroke(7));
    final gutterY = cells.first.bottom + kGridPhotoGutter / 2;
    final gutterX = cells.first.right + kGridPhotoGutter / 2;
    canvas.drawLine(Offset(sheet.left, gutterY), Offset(sheet.right, gutterY), _stroke(7));
    canvas.drawLine(Offset(gutterX, sheet.top), Offset(gutterX, sheet.bottom), _stroke(7));
    for (var index = 0; index < cells.length; index++) {
      final tag = Rect.fromLTWH(cells[index].left + 6, cells[index].top + 6, 32, 32);
      canvas.drawRect(tag, _fill());
      _labelCentered(canvas, '${index + 1}', tag.center, size: 20, color: _paper);
    }
    _burst(canvas, Offset(cells.last.right - 48, cells.last.bottom - 48), 38, word: 'POW!');
  }
}

/// A 35 mm contact sheet: sprocket rails, frame edges and rotated frame codes.
class _ContactSheetPainter extends _FramePainter {
  const _ContactSheetPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _gridCells(window);
    _sprocketBand(canvas, Rect.fromLTWH(0, 0, 52, size.height), holeWidth: 16, holeHeight: 20);
    _sprocketBand(canvas, Rect.fromLTWH(size.width - 52, 0, 52, size.height),
        holeWidth: 16, holeHeight: 20);
    for (final cell in cells) {
      canvas.drawRect(cell, _stroke(3));
    }
    for (var index = 0; index < cells.length; index++) {
      canvas.save();
      canvas.translate(26, cells[index].center.dy);
      canvas.rotate(-math.pi / 2);
      _labelCentered(canvas, '0${index + 1}', Offset.zero,
          size: 17, letterSpacing: 2, color: _paper);
      canvas.restore();
    }
  }
}

/// A photo booth sheet: thin grid rules, crop marks and a 4-up footer band.
class _PhotoBoothSheetPainter extends _FramePainter {
  const _PhotoBoothSheetPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _gridCells(window);
    final gutterX = cells.first.right + kGridPhotoGutter / 2;
    final gutterY = cells.first.bottom + kGridPhotoGutter / 2;
    canvas.drawLine(Offset(gutterX, window.top), Offset(gutterX, window.bottom), _stroke(3));
    canvas.drawLine(Offset(window.left, gutterY), Offset(window.right, gutterY), _stroke(3));
    _cropMarks(canvas, window, leg: 20, outset: 8);

    final band = window.bottom;
    _dashedLine(canvas, Offset(window.left, band + 12), Offset(window.right, band + 12),
        width: 3, dash: 10, gap: 7);
    _labelLeft(canvas, 'SKYELOOP', Offset(window.left, band + 24),
        size: 22, weight: FontWeight.w800, letterSpacing: 3);
    _labelRight(canvas, '4-UP SHEET', Offset(window.right, band + 26), size: 18, letterSpacing: 2);
    _dashedLine(canvas, Offset(window.left, band + 56), Offset(window.right, band + 56),
        width: 3, dash: 10, gap: 7);
    _labelCentered(canvas, 'KEEP THIS MOMENT', Offset(window.center.dx, band + 78),
        size: 17, letterSpacing: 2);
  }
}

/// A scrapbook page: captioned cards held down with strips of washi tape.
class _PolaroidCollagePainter extends _FramePainter {
  const _PolaroidCollagePainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _gridCells(window);
    const captions = ['• ONE •', '• TWO •', '• THREE •', '• FOUR •'];
    for (var index = 0; index < cells.length; index++) {
      _captionStrip(canvas, cells[index], captions[index], height: 28);
    }
    for (final cell in cells) {
      final onRight = cell.center.dx > window.center.dx;
      final anchor = onRight
          ? cell.topRight + const Offset(-20, 20)
          : cell.topLeft + const Offset(20, 20);
      _tape(canvas, anchor, onRight ? math.pi / 5 : -math.pi / 5);
    }
    _dashedRect(canvas, _sheet(size, 10), width: 3, dash: 12, gap: 9);
    _star(canvas, Offset(size.width - 17, window.center.dy), 8);
    _star(canvas, Offset(window.center.dx, size.height - 17), 8);
  }
}

/// A monitor wall: four bezelled screens, each with a CAM / REC header bar.
class _CctvWallPainter extends _FramePainter {
  const _CctvWallPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _gridCells(window);
    for (var index = 0; index < cells.length; index++) {
      final cell = cells[index];
      canvas.drawRRect(
        RRect.fromRectAndRadius(cell.inflate(4), const Radius.circular(8)),
        _stroke(5),
      );
      final bar = Rect.fromLTWH(cell.left + 2, cell.top + 2, cell.width - 4, 30);
      canvas.drawRect(bar, _fill());
      _labelLeft(canvas, 'CAM ${index + 1}', Offset(bar.left + 8, bar.top + 6),
          size: 16, letterSpacing: 1.5, color: _paper);
      canvas.drawCircle(Offset(bar.right - 58, bar.center.dy), 5, _paperFill());
      _labelRight(canvas, 'REC', Offset(bar.right - 8, bar.top + 6),
          size: 16, letterSpacing: 2, color: _paper);
    }
  }
}

/// A yearbook page: masthead, caption rules under each portrait and a footer.
class _YearbookPagePainter extends _FramePainter {
  const _YearbookPagePainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _gridCells(window);
    final sheet = _sheet(size);
    canvas.drawLine(Offset(sheet.left + 4, 14), Offset(sheet.right - 4, 14), _stroke(3));
    _labelCentered(canvas, 'YEARBOOK', Offset(sheet.center.dx, 44),
        size: 46, weight: FontWeight.w800, letterSpacing: 6);
    canvas.drawLine(Offset(sheet.left + 4, 72), Offset(sheet.right - 4, 72), _stroke(3));

    for (final cell in cells) {
      _captionStrip(canvas, cell, null, height: 26);
    }
    final band = window.bottom;
    _dashedLine(canvas, Offset(window.left, band + 12), Offset(window.right, band + 12),
        width: 3, dash: 10, gap: 7);
    _labelLeft(canvas, 'SKYELOOP VENDO', Offset(window.left, band + 24),
        size: 18, letterSpacing: 2);
    _labelRight(canvas, 'PHOTO DAY', Offset(window.right, band + 25), size: 17, letterSpacing: 2);
  }
}

/// Four mini boarding passes above one shared footer band.
class _TicketQuartetPainter extends _FramePainter {
  const _TicketQuartetPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _gridCells(window);
    final sheet = Rect.fromLTRB(10, 10, size.width - 10, size.height - 10);
    canvas.drawRRect(RRect.fromRectAndRadius(sheet, const Radius.circular(20)), _stroke(4));

    for (final cell in cells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cell.inflate(3), const Radius.circular(10)),
        _stroke(3),
      );
      _plane(canvas, cell.topLeft + const Offset(22, 22), 10);
      final strip = Rect.fromLTWH(cell.left, cell.bottom - 30, cell.width, 30);
      canvas.drawRect(strip, _paperFill());
      canvas.drawLine(strip.topLeft, strip.topRight, _stroke(3));
      _labelLeft(canvas, '12A', Offset(strip.left + 8, strip.top + 7), size: 16, letterSpacing: 1.5);
      _barcode(canvas, Rect.fromLTWH(strip.right - 78, strip.top + 7, 70, 16));
    }

    final band = window.bottom;
    _labelCentered(canvas, 'BOARDING PASS', Offset(window.center.dx, band + 20),
        size: 22, weight: FontWeight.w800, letterSpacing: 3);
    _dashedLine(canvas, Offset(sheet.left + 6, band + 44), Offset(sheet.right - 6, band + 44),
        width: 3, dash: 12, gap: 8);
    canvas.drawCircle(Offset(sheet.left + 6, band + 44), 9, _paperFill());
    canvas.drawCircle(Offset(sheet.right - 6, band + 44), 9, _paperFill());
    _labelLeft(canvas, 'FLIGHT SL-2026', Offset(window.left, band + 58), size: 18, letterSpacing: 1.5);
    _labelRight(canvas, 'GATE 12  SEAT 4A', Offset(window.right, band + 59),
        size: 17, letterSpacing: 1.5);
  }
}

/// A block of four perforated stamps with printed denominations.
class _StampBlockPainter extends _FramePainter {
  const _StampBlockPainter(super.inset);

  @override
  void paint(Canvas canvas, Size size) {
    final window = _window(size);
    final cells = _gridCells(window);
    _perforatedEdge(canvas, Rect.fromLTRB(16, 16, size.width - 16, size.height - 16));
    final gutterX = cells.first.right + kGridPhotoGutter / 2;
    final gutterY = cells.first.bottom + kGridPhotoGutter / 2;
    _perforatedRule(canvas, Rect.fromLTRB(gutterX - 5, window.top, gutterX + 5, window.bottom));
    _perforatedRule(canvas, Rect.fromLTRB(window.left, gutterY - 5, window.right, gutterY + 5));
    for (final cell in cells) {
      final box = Rect.fromLTWH(cell.left + 8, cell.bottom - 34, 40, 26);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), _stroke(3));
      _labelCentered(canvas, '20', box.center, size: 16, letterSpacing: 1);
    }
  }
}