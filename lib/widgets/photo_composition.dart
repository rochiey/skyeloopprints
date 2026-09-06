import 'dart:io';

import 'package:flutter/material.dart';

import '../models/editor_item.dart';
import '../models/photo_session.dart';
import '../models/pricing_tier.dart';
import '../theme/skyeloop_theme.dart';

class PhotoComposition extends StatefulWidget {
  const PhotoComposition({
    super.key,
    required this.session,
    required this.onChanged,
    this.venueName = 'Skye Loop Vendo',
    this.interactive = true,
  });

  final PhotoSession session;
  final VoidCallback onChanged;

  /// The cafe / venue name shown as the header above the photo.
  final String venueName;
  final bool interactive;

  @override
  PhotoCompositionState createState() => PhotoCompositionState();
}

class PhotoCompositionState extends State<PhotoComposition> {
  /// The composition is always laid out at print size (576 px wide = the
  /// printer's 576-dot line), and the preview scales it down with a FittedBox.
  static const double _printWidth = 576;
  static const double _standardHeight = 821; // single/grid: portrait photo area (~4:5)
  static const double _stripHeight = 1385; // 3 photos stacked at 4:3

  /// Fixed header band: room for the cafe name at 5 mm (single line of 40 px).
  static const double _headerBand = 72;
  /// Fixed footer band holding the brand + date.
  static const double _footerBand = 56;

  static const TextStyle _headerStyle = TextStyle(
    fontFamily: 'Poppins',
    color: SkyeColors.ink,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.1,
  );
  static const TextStyle _footerStyle = TextStyle(
    fontFamily: 'Poppins',
    color: SkyeColors.ink,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );
  static const TextStyle _dateStyle = TextStyle(
    fontFamily: 'Poppins',
    color: SkyeColors.blue,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
  );

  /// The id of the currently selected text/sticker. Selected items show a
  /// border plus resize and delete controls; clear it before exporting so the
  /// editing chrome never ends up in the print.
  String? _selectedId;

  void clearSelection() {
    if (_selectedId == null) return;
    setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.session.startedAt;
    final dateLabel = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-${(date.year % 100).toString().padLeft(2, '0')}';
    return widget.session.tier.layout == LayoutType.strip
        ? _buildStrip(context, dateLabel)
        : _buildStandard(context, dateLabel);
  }

  Widget _buildStandard(BuildContext context, String dateLabel) {
    return Container(
      width: _printWidth,
      height: _standardHeight,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _headerBand,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.venueName.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _headerStyle,
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: _headerBand,
            bottom: _footerBand,
            child: _PhotoGrid(session: widget.session),
          ),
          Positioned(
            bottom: 14,
            left: 8,
            child: const Text('SkyeLoop', style: _footerStyle),
          ),
          Positioned(
            bottom: 14,
            right: 8,
            child: Text(
              dateLabel,
              style: _dateStyle,
            ),
          ),
          for (final item in widget.session.editorItems)
            Positioned(
              left: item.offset.dx,
              top: item.offset.dy,
              child: _EditableOverlay(
                item: item,
                enabled: widget.interactive,
                selected: widget.interactive && item.id == _selectedId,
                onSelect: () => setState(() => _selectedId = item.id),
                onDeselect: () => setState(() => _selectedId = null),
                onScaleChanged: (scale) => setState(() => item.scale = scale),
                onDelete: () => setState(() {
                  widget.session.editorItems.remove(item);
                  _selectedId = null;
                }),
              ),
            ),
        ],
      ),
    );
  }

  /// Three-photo strip: cafe name, then 3 landscape 4:3 photos stacked
  /// vertically, then the footer.
  Widget _buildStrip(BuildContext context, String dateLabel) {
    return Container(
      width: _printWidth,
      height: _stripHeight,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: _headerBand,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        widget.venueName.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _headerStyle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < widget.session.photoPaths.length; index++) ...[
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _PhotoCell(path: widget.session.photoPaths[index]),
                  ),
                  if (index != widget.session.photoPaths.length - 1) const SizedBox(height: 8),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SkyeLoop', style: _footerStyle),
                      Text(
                        dateLabel,
                        style: _dateStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final item in widget.session.editorItems)
            Positioned(
              left: item.offset.dx,
              top: item.offset.dy,
              child: _EditableOverlay(
                item: item,
                enabled: widget.interactive,
                selected: widget.interactive && item.id == _selectedId,
                onSelect: () => setState(() => _selectedId = item.id),
                onDeselect: () => setState(() => _selectedId = null),
                onScaleChanged: (scale) => setState(() => item.scale = scale),
                onDelete: () => setState(() {
                  widget.session.editorItems.remove(item);
                  _selectedId = null;
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.session});
  final PhotoSession session;

  @override
  Widget build(BuildContext context) {
    final photos = session.photoPaths;
    if (session.tier.layout == LayoutType.single) {
      return _PhotoCell(path: photos.first);
    }
    if (session.tier.layout == LayoutType.strip) {
      return Column(
        children: [
          for (var index = 0; index < photos.length; index++) ...[
            Expanded(child: _PhotoCell(path: photos[index])),
            if (index != photos.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _PhotoCell(path: photos[0])),
              const SizedBox(width: 8),
              Expanded(child: _PhotoCell(path: photos[1])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _PhotoCell(path: photos[2])),
              const SizedBox(width: 8),
              Expanded(child: _PhotoCell(path: photos[3])),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: SkyeColors.mist,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}

class _EditableOverlay extends StatefulWidget {
  const _EditableOverlay({
    required this.item,
    required this.enabled,
    required this.selected,
    required this.onSelect,
    required this.onDeselect,
    required this.onScaleChanged,
    required this.onDelete,
  });

  final EditorItem item;
  final bool enabled;

  /// Whether the item is currently selected (shows editing controls).
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDeselect;
  final ValueChanged<double> onScaleChanged;
  final VoidCallback onDelete;

  @override
  State<_EditableOverlay> createState() => _EditableOverlayState();
}

class _EditableOverlayState extends State<_EditableOverlay> {
  double _startingScale = 1;

  static const double _minScale = .45;
  static const double _maxScale = 3.5;

  void _resizeBy(double delta) {
    final item = widget.item;
    item.scale = (item.scale + delta).clamp(_minScale, _maxScale);
    widget.onScaleChanged(item.scale);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    Widget content = Transform.scale(
      scale: item.scale,
      alignment: Alignment.center,
      child: item.type == EditorItemType.sticker
          ? Text(item.value, style: const TextStyle(fontSize: 52))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.value,
                style: TextStyle(
                  color: item.color,
                  fontFamily: item.fontFamily,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );

    if (widget.selected) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SkyeColors.blue, width: 2),
            ),
            child: content,
          ),
          Material(
            color: Colors.white,
            elevation: 4,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Smaller',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _resizeBy(-0.25),
                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                    ),
                  ),
                  Tooltip(
                    message: 'Bigger',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _resizeBy(0.25),
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                    ),
                  ),
                  Tooltip(
                    message: 'Delete',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: !widget.enabled
          ? null
          : () {
              if (widget.selected) {
                widget.onDeselect();
              } else {
                widget.onSelect();
              }
            },
      onScaleStart: widget.enabled
          ? (_) {
              _startingScale = item.scale;
            }
          : null,
      onScaleUpdate: widget.enabled
          ? (details) {
              item.scale = (_startingScale * details.scale).clamp(_minScale, _maxScale);
              item.offset += details.focalPointDelta;
              widget.onScaleChanged(item.scale);
            }
          : null,
      child: content,
    );
  }
}
