import 'dart:ui';

enum EditorItemType { text, sticker }

class EditorItem {
  EditorItem({
    required this.id,
    required this.type,
    required this.value,
    this.offset = const Offset(80, 80),
    this.scale = 1,
    this.color = const Color(0xFF102A43),
    this.fontFamily,
  });

  final String id;
  final EditorItemType type;
  String value;
  Offset offset;
  double scale;
  Color color;
  String? fontFamily;
}

