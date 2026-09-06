/// A themed group of emoji stickers shown in the editor's sticker sheet.
class StickerCategory {
  const StickerCategory(this.name, this.emoji, this.stickers);

  final String name;
  final String emoji;
  final List<String> stickers;
}

const List<StickerCategory> kStickerCategories = [
  StickerCategory('Party', '🎉', [
    '🥳', '🎉', '🎈', '🎂', '🪅', '🎊', '🎁', '🪩', '🎤', '🎶', '🎵', '🥂',
  ]),
  StickerCategory('Love', '🩷', [
    '❤️', '🩷', '💜', '💙', '💚', '🧡', '💛', '🫶', '😍', '🥰', '😘', '💘',
  ]),
  StickerCategory('Cute', '🐻', [
    '🐻', '🐰', '🐱', '🐶', '🐼', '🦊', '🐸', '🐵', '🦄', '🐷', '🐨', '🐹',
  ]),
  StickerCategory('Nature', '🌸', [
    '🌸', '🌼', '🌻', '🍀', '🌈', '☁️', '🌙', '⭐', '🌟', '✨', '🌴', '🌊',
  ]),
  StickerCategory('Food', '🍩', [
    '☕', '🧁', '🍩', '🍓', '🍒', '🍦', '🍭', '🍰', '🍪', '🧋', '🍕', '🍔',
  ]),
  StickerCategory('Fun', '😎', [
    '😎', '🤪', '😜', '🤩', '😂', '🙃', '🤙', '👍', '✌️', '🤟', '📸', '🔥',
  ]),
];
