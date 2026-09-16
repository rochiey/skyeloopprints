import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/skyeloop_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    this.imagePath,
    this.size = 230,
    this.maxWidth,
    this.maxHeight,
    super.key,
  });

  final String? imagePath;

  /// Diameter of the built-in mark. Also the default size of the box an
  /// uploaded logo may fill when [maxWidth]/[maxHeight] are not given.
  final double size;

  /// Box the client's uploaded artwork may use. Defaults to a [size] square.
  final double? maxWidth;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path != null && File(path).existsSync()) {
      // The client's own artwork is shown whole: no circular crop, scaled to
      // fill as much of the given box as its own aspect ratio allows, so a
      // large logo is never shrunk to a circle again.
      return SizedBox(
        width: maxWidth ?? size,
        height: maxHeight ?? size,
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(child: _BuiltInMark(size: size)),
        ),
      );
    }
    return _BuiltInMark(size: size);
  }
}

class _BuiltInMark extends StatelessWidget {
  const _BuiltInMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SkyeColors.paper,
        border: Border.all(color: SkyeColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.sentiment_very_satisfied_rounded,
              size: size * .54, color: SkyeColors.ink),
          Positioned(
            top: size * .18,
            left: size * .12,
            child: Text(
              'Skye',
              style: TextStyle(
                color: SkyeColors.blue,
                fontSize: size * .18,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Positioned(
            right: size * .13,
            child: Icon(Icons.camera_rounded,
                size: size * .24, color: SkyeColors.amber),
          ),
          Positioned(
            bottom: size * .10,
            child: Text(
              '•  S K Y E  L O O P  V E N D O  •',
              style: TextStyle(
                color: SkyeColors.blue,
                fontSize: size * .047,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

