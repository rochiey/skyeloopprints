import 'package:flutter/widgets.dart';

import 'pricing_tier.dart';

/// Gaps the composition puts between photos. The frame painters reuse these,
/// so the artwork gutters line up exactly with the photo edges.
const double kGridPhotoGutter = 8;
const double kStripPhotoGutter = 8;

/// Aspect ratio of the three-photo strip's cells (landscape 4:3).
const double kStripPhotoAspect = 4 / 3;

/// Every frame the kiosk can print around a finished composition.
///
/// A frame is vector art drawn in solid black on white. The print pipeline
/// reduces the composition to a 1-bit halftone (576 dots wide, Atkinson error
/// diffusion behind a lifted tone curve), so every style deliberately uses
/// strokes of at least 3 px and text of at least 16 px: thinner marks are
/// lifted to a mid grey and then quantised away into a broken dotted line.
///
/// Styles are grouped by the layout they are designed for, and the picker only
/// ever offers the group that matches the session's layout.
enum PrintBorderId {
  none,

  // ---- Single photo: one portrait, 540 x 675 px at print scale ----
  wantedPoster,
  musicPlayer,
  polaroid,
  boardingPass,
  postageStamp,
  magazineCover,
  arcadeTv,
  passportStamp,

  // ---- Three-photo strip: three 4:3 photos stacked ----
  filmStrip,
  filmRails,
  photoBoothStrip,
  comicStrip,
  polaroidStack,
  receiptRoll,
  stampSheet,

  // ---- Four-photo grid: a 2 x 2 sheet ----
  comicGrid,
  contactSheet,
  photoBoothSheet,
  polaroidCollage,
  cctvWall,
  yearbookPage,
  ticketQuartet,
  stampBlock,
}

/// A frame style plus the ring of white space it reserves around the photos.
class PrintBorder {
  const PrintBorder({
    required this.id,
    required this.label,
    required this.blurb,
    required this.inset,
  });

  final PrintBorderId id;

  /// Short name shown on the picker card.
  final String label;

  /// One-line description shown under the name.
  final String blurb;

  /// The ring the frame needs around the photo area. The photos are laid out
  /// inside whatever is left, which is what makes a frame a single piece that
  /// wraps every photo on the sheet. The painters never draw outside the box
  /// this inset creates, so every style stays inside its own layout's
  /// available height (the strip in particular only has a few pixels of slack
  /// and takes its room from the sides).
  final EdgeInsets inset;
}

const PrintBorder _plainBorder = PrintBorder(
  id: PrintBorderId.none,
  label: 'No frame',
  blurb: 'Plain photo, edge to edge.',
  inset: EdgeInsets.zero,
);

/// The frames offered for each layout, in picker order.
const Map<LayoutType, List<PrintBorder>> kLayoutBorders = {
  LayoutType.single: [
    _plainBorder,
    PrintBorder(
      id: PrintBorderId.wantedPoster,
      label: 'Wanted poster',
      blurb: 'Dead or alive + bounty bar.',
      inset: EdgeInsets.fromLTRB(22, 96, 22, 104),
    ),
    PrintBorder(
      id: PrintBorderId.musicPlayer,
      label: 'Music player',
      blurb: 'Now playing bar + waveform.',
      inset: EdgeInsets.fromLTRB(20, 78, 20, 108),
    ),
    PrintBorder(
      id: PrintBorderId.polaroid,
      label: 'Polaroid',
      blurb: 'Instant frame, wide chin.',
      inset: EdgeInsets.fromLTRB(22, 22, 22, 74),
    ),
    PrintBorder(
      id: PrintBorderId.boardingPass,
      label: 'Airplane ticket',
      blurb: 'Boarding pass + barcode stub.',
      inset: EdgeInsets.fromLTRB(20, 56, 20, 116),
    ),
    PrintBorder(
      id: PrintBorderId.postageStamp,
      label: 'Postage stamp',
      blurb: 'Perforated edge, value box.',
      inset: EdgeInsets.fromLTRB(30, 30, 30, 58),
    ),
    PrintBorder(
      id: PrintBorderId.magazineCover,
      label: 'Magazine cover',
      blurb: 'Masthead + cover lines.',
      inset: EdgeInsets.fromLTRB(20, 92, 20, 62),
    ),
    PrintBorder(
      id: PrintBorderId.arcadeTv,
      label: 'Arcade screen',
      blurb: 'Cabinet bezel, player 1 bar.',
      inset: EdgeInsets.fromLTRB(34, 34, 34, 84),
    ),
    PrintBorder(
      id: PrintBorderId.passportStamp,
      label: 'Passport stamp',
      blurb: 'Entry stamp over the corner.',
      inset: EdgeInsets.fromLTRB(18, 18, 18, 18),
    ),
  ],
  LayoutType.strip: [
    _plainBorder,
    PrintBorder(
      id: PrintBorderId.filmStrip,
      label: 'Film strip',
      blurb: 'Sprocket rails down the sides.',
      inset: EdgeInsets.fromLTRB(46, 14, 46, 14),
    ),
    PrintBorder(
      id: PrintBorderId.filmRails,
      label: 'Film rails',
      blurb: 'Light rails + frame numbers.',
      inset: EdgeInsets.fromLTRB(30, 12, 30, 12),
    ),
    PrintBorder(
      id: PrintBorderId.photoBoothStrip,
      label: 'Photo booth',
      blurb: 'Crop marks + tear-off edges.',
      inset: EdgeInsets.fromLTRB(18, 26, 18, 26),
    ),
    PrintBorder(
      id: PrintBorderId.comicStrip,
      label: 'Comic strip',
      blurb: 'Ink panels 1 2 3 + POW!',
      inset: EdgeInsets.fromLTRB(22, 22, 22, 22),
    ),
    PrintBorder(
      id: PrintBorderId.polaroidStack,
      label: 'Polaroid stack',
      blurb: 'Three cards with captions.',
      inset: EdgeInsets.fromLTRB(26, 18, 26, 18),
    ),
    PrintBorder(
      id: PrintBorderId.receiptRoll,
      label: 'Receipt roll',
      blurb: 'Torn edges + thank you bar.',
      inset: EdgeInsets.fromLTRB(30, 34, 30, 34),
    ),
    PrintBorder(
      id: PrintBorderId.stampSheet,
      label: 'Stamp sheet',
      blurb: 'Three perforated stamps.',
      inset: EdgeInsets.fromLTRB(34, 22, 34, 22),
    ),
  ],
  LayoutType.grid: [
    _plainBorder,
    PrintBorder(
      id: PrintBorderId.comicGrid,
      label: 'Comic panels',
      blurb: 'Four inked panels + POW!',
      inset: EdgeInsets.fromLTRB(22, 22, 22, 22),
    ),
    PrintBorder(
      id: PrintBorderId.contactSheet,
      label: 'Contact sheet',
      blurb: 'Film frame numbers, 01-04.',
      inset: EdgeInsets.fromLTRB(52, 18, 52, 18),
    ),
    PrintBorder(
      id: PrintBorderId.photoBoothSheet,
      label: 'Photo booth sheet',
      blurb: 'Crop marks + 4-up footer.',
      inset: EdgeInsets.fromLTRB(20, 20, 20, 74),
    ),
    PrintBorder(
      id: PrintBorderId.polaroidCollage,
      label: 'Polaroid collage',
      blurb: 'Taped cards with captions.',
      inset: EdgeInsets.fromLTRB(26, 26, 26, 26),
    ),
    PrintBorder(
      id: PrintBorderId.cctvWall,
      label: 'CCTV wall',
      blurb: 'Four monitors with REC bars.',
      inset: EdgeInsets.fromLTRB(26, 26, 26, 26),
    ),
    PrintBorder(
      id: PrintBorderId.yearbookPage,
      label: 'Yearbook page',
      blurb: 'Name rules + class of year.',
      inset: EdgeInsets.fromLTRB(20, 76, 20, 66),
    ),
    PrintBorder(
      id: PrintBorderId.ticketQuartet,
      label: 'Ticket quartet',
      blurb: 'Four mini boarding passes.',
      inset: EdgeInsets.fromLTRB(20, 20, 20, 96),
    ),
    PrintBorder(
      id: PrintBorderId.stampBlock,
      label: 'Stamp block',
      blurb: 'Four perforated stamps.',
      inset: EdgeInsets.fromLTRB(34, 34, 34, 34),
    ),
  ],
};

/// The frames offered for [layout], always starting with "No frame".
List<PrintBorder> bordersForLayout(LayoutType layout) =>
    kLayoutBorders[layout] ?? const <PrintBorder>[_plainBorder];

/// Looks a frame up in every layout's group, returning null when unknown.
PrintBorder? borderById(PrintBorderId id) {
  for (final borders in kLayoutBorders.values) {
    for (final border in borders) {
      if (border.id == id) return border;
    }
  }
  return null;
}

/// Whether [id] may be printed on [layout]. A session never carries a frame
/// designed for a different layout: the composition falls back to a plain
/// photo instead of drawing artwork that belongs somewhere else.
bool borderFitsLayout(PrintBorderId id, LayoutType layout) {
  if (id == PrintBorderId.none) return true;
  return bordersForLayout(layout).any((border) => border.id == id);
}
