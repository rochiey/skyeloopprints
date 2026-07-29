import 'dart:typed_data';

import 'editor_item.dart';
import 'pricing_tier.dart';

class PhotoSession {
  PhotoSession({required this.tier})
      : id = DateTime.now().microsecondsSinceEpoch.toString(),
        startedAt = DateTime.now();

  final String id;
  final DateTime startedAt;
  final PricingTier tier;
  final List<String> photoPaths = [];
  final List<EditorItem> editorItems = [];
  int copies = 1;
  Uint8List? flattenedImage;
  String? flattenedImagePath;
}

