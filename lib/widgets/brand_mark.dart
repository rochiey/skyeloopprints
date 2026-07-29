import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/skyeloop_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.imagePath, this.size = 230, super.key});

  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path != null && File(path).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _BuiltInMark(size: size),
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

