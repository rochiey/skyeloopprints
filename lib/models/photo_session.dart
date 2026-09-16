import 'dart:typed_data';

import 'editor_item.dart';
import 'pricing_tier.dart';
import 'print_border.dart';

class PhotoSession {
  PhotoSession({required this.tier})
      : id = DateTime.now().microsecondsSinceEpoch.toString(),
        startedAt = DateTime.now();

  final String id;
  final DateTime startedAt;
  final PricingTier tier;
  final List<String> photoPaths = [];
  final List<EditorItem> editorItems = [];

  /// The one-piece frame printed around this session's photo(s). Only frames
  /// offered for [tier]'s layout are drawn (see [borderFitsLayout]).
  PrintBorderId border = PrintBorderId.none;
  int copies = 1;
  Uint8List? flattenedImage;
  String? flattenedImagePath;
}

