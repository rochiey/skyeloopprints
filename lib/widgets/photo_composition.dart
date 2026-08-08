import 'dart:io';

import 'package:flutter/material.dart';

import '../models/editor_item.dart';
import '../models/photo_session.dart';
import '../models/pricing_tier.dart';
import '../theme/skyeloop_theme.dart';

class PhotoComposition extends StatelessWidget {
  const PhotoComposition({
    required this.session,
    required this.onChanged,
    this.interactive = true,
    super.key,
  });

  final PhotoSession session;
  final VoidCallback onChanged;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final date = session.startedAt;
    final dateLabel = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-${(date.year % 100).toString().padLeft(2, '0')}';
    return AspectRatio(
      aspectRatio: .78,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  bottom: constraints.maxHeight * .17,
                  child: _PhotoGrid(session: session),
                ),
                Positioned(
                  bottom: constraints.maxHeight * .055,
                  left: 8,
                  child: const Text(
                    'SkyeLoop',
                    style: TextStyle(
                      color: SkyeColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                Positioned(
                  bottom: constraints.maxHeight * .045,
                  right: 8,
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      color: SkyeColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                for (final item in session.editorItems)
                  Positioned(
                    left: item.offset.dx,
                    top: item.offset.dy,
                    child: _EditableOverlay(
                      item: item,
                      enabled: interactive,
                      onChanged: onChanged,
                    ),
                  ),
              ],
            );
          },
        ),
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
    required this.onChanged,
  });

  final EditorItem item;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  State<_EditableOverlay> createState() => _EditableOverlayState();
}

class _EditableOverlayState extends State<_EditableOverlay> {
  double _startingScale = 1;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onScaleStart: widget.enabled
          ? (_) {
              _startingScale = item.scale;
            }
          : null,
      onScaleUpdate: widget.enabled
          ? (details) {
              item.scale = (_startingScale * details.scale).clamp(.45, 3.5);
              item.offset += details.focalPointDelta;
              widget.onChanged();
            }
          : null,
      child: Transform.scale(
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
      ),
    );
  }
}
