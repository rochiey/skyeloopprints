import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app.dart';
import '../../models/editor_item.dart';
import '../../models/pricing_tier.dart';
import '../../models/print_border.dart';
import '../../models/stickers.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/kiosk_shell.dart';
import '../../widgets/photo_composition.dart';
import '../../widgets/print_border_frame.dart';
import '../../widgets/screen_heading.dart';
import 'printing_screen.dart';

class PreviewEditScreen extends StatefulWidget {
  const PreviewEditScreen({super.key});

  @override
  State<PreviewEditScreen> createState() => _PreviewEditScreenState();
}

class _PreviewEditScreenState extends State<PreviewEditScreen> {
  final _compositionKey = GlobalKey<PhotoCompositionState>();
  bool _exporting = false;

  Future<void> _addText() async {
    final valueController = TextEditingController();
    var selectedColor = SkyeColors.blue;
    String? selectedFont = 'sans-serif';
    final result = await showDialog<EditorItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add a message'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: valueController,
                  autofocus: true,
                  maxLength: 36,
                  decoration: const InputDecoration(labelText: 'Your text', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedFont,
                  decoration: const InputDecoration(labelText: 'Font style', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'sans-serif', child: Text('Friendly bold')),
                    DropdownMenuItem(value: 'serif', child: Text('Classic serif')),
                    DropdownMenuItem(value: 'monospace', child: Text('Retro mono')),
                    DropdownMenuItem(value: 'cursive', child: Text('Handwritten')),
                  ],
                  onChanged: (value) => selectedFont = value,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final color in const [
                      SkyeColors.ink,
                      SkyeColors.blue,
                      Color(0xFFC62828),
                      Color(0xFF2E7D32),
                      Color(0xFF7B1FA2),
                      SkyeColors.amber,
                    ])
                      InkWell(
                        onTap: () => setDialogState(() => selectedColor = color),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color ? Colors.white : Colors.transparent,
                              width: 4,
                            ),
                            boxShadow: selectedColor == color
                                ? const [BoxShadow(color: Colors.black38, blurRadius: 4)]
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (valueController.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  EditorItem(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    type: EditorItemType.text,
                    value: valueController.text.trim(),
                    color: selectedColor,
                    fontFamily: selectedFont,
                    offset: const Offset(55, 65),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    valueController.dispose();
    if (result == null || !mounted) return;
    setState(() => AppScope.of(context, listen: false).session!.editorItems.add(result));
  }

  Future<void> _addSticker() async {
    final sticker = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DefaultTabController(
        length: kStickerCategories.length,
        child: SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Pick a sticker',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final category in kStickerCategories)
                      Tab(text: category.name),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final category in kStickerCategories)
                        GridView.count(
                          padding: const EdgeInsets.all(18),
                          crossAxisCount: 6,
                          children: [
                            for (final value in category.stickers)
                              InkWell(
                                onTap: () => Navigator.pop(context, value),
                                borderRadius: BorderRadius.circular(12),
                                child: Center(
                                  child: Text(value,
                                      style: const TextStyle(fontSize: 38)),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (sticker == null || !mounted) return;
    final session = AppScope.of(context, listen: false).session!;
    setState(() {
      session.editorItems.add(
        EditorItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: EditorItemType.sticker,
          value: sticker,
          offset: Offset(60 + Random().nextDouble() * 80, 70 + Random().nextDouble() * 120),
        ),
      );
    });
  }

  /// Opens the frame picker. Only frames designed for the session's layout are
  /// offered: a film-strip rail makes no sense around one photo, and a poster
  /// banner makes no sense split across four.
  Future<void> _chooseBorder() async {
    final session = AppScope.of(context, listen: false).session!;
    final borders = bordersForLayout(session.tier.layout);
    final noun = switch (session.tier.layout) {
      LayoutType.single => 'your photo',
      LayoutType.strip => 'all three photos',
      LayoutType.grid => 'all four photos',
    };
    final picked = await showModalBottomSheet<PrintBorderId>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 470,
          child: Column(
            children: [
              Text('Pick a frame', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'One frame wraps $noun. Frames print in black and white, '
                  'like the rest of your photo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black.withValues(alpha: .6)),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 168,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: .76,
                  ),
                  itemCount: borders.length,
                  itemBuilder: (context, index) {
                    final spec = borders[index];
                    final selected = session.border == spec.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(context, spec.id),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? SkyeColors.blue
                                : Colors.black.withValues(alpha: .14),
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(child: _BorderPreview(tier: session.tier, spec: spec)),
                            const SizedBox(height: 6),
                            Text(spec.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(spec.blurb,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
                                    color: Colors.black.withValues(alpha: .55))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => session.border = picked);
  }

  Future<void> _exportAndPrint() async {
    final app = AppScope.of(context, listen: false);
    final session = app.session!;
    setState(() => _exporting = true);
    try {
      // Hide the selection border/toolbar so it is never captured in the print.
      _compositionKey.currentState?.clearSelection();
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _compositionKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixelRatio = 576 / boundary.size.width;
      final image = await boundary.toImage(pixelRatio: pixelRatio.clamp(1, 4));
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      session.flattenedImage = bytes;
      session.flattenedImagePath = await app.sessionFileService.saveFinalImage(session.id, bytes);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PrintingScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not prepare the photo: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final session = app.session!;
    final maxCopies = app.config.copiesLimitEnabled
        ? app.config.maxCopiesFor(session.tier)
        : null;
    return PopScope(
      canPop: false,
      child: KioskShell(
        header: const ScreenHeading(
          title: 'Make it yours',
          subtitle: 'Drag and pinch text or stickers. Your print includes the white writing margin.',
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Copies', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            IconButton.filledTonal(
              onPressed: session.copies > 1 ? () => setState(() => session.copies--) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(width: 44, child: Text('${session.copies}', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
            IconButton.filledTonal(
              onPressed: (maxCopies == null || session.copies < maxCopies)
                  ? () => setState(() => session.copies++)
                  : null,
              icon: const Icon(Icons.add),
            ),
            if (maxCopies != null)
              Text('max $maxCopies', style: TextStyle(
                  fontSize: 13, color: Colors.black.withValues(alpha: .55))),
            const SizedBox(width: 26),
            FilledButton.icon(
              onPressed: _exporting ? null : _exportAndPrint,
              icon: _exporting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print_rounded),
              label: const Text('Print'),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final portrait = constraints.maxWidth < 700;
            if (portrait) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 470, maxHeight: 600),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10))],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: RepaintBoundary(
                              key: _compositionKey,
                              child: PhotoComposition(
                                session: session,
                                venueName: app.config.venueName,
                                onChanged: () => setState(() {}),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.tonalIcon(onPressed: _addText,
                              icon: const Icon(Icons.text_fields), label: const Text('Add text')),
                          FilledButton.tonalIcon(onPressed: _addSticker,
                              icon: const Icon(Icons.emoji_emotions_outlined), label: const Text('Add sticker')),
                          FilledButton.tonalIcon(onPressed: _chooseBorder,
                              icon: const Icon(Icons.crop_square_rounded), label: const Text('Border')),
                          OutlinedButton.icon(
                            onPressed: session.editorItems.isEmpty
                                ? null
                                : () => setState(() => session.editorItems.removeLast()),
                            icon: const Icon(Icons.undo),
                            label: const Text('Undo last'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Card(
                      color: SkyeColors.mist,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                            'Tip: tap a sticker or text to select it. Drag to move '
                            'it, tap − / + to resize, or pinch with two fingers. '
                            'Border wraps the photos in one printed frame.'),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Row(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10))],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: RepaintBoundary(
                            key: _compositionKey,
                            child: PhotoComposition(
                              session: session,
                              venueName: app.config.venueName,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 210,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.tonalIcon(onPressed: _addText,
                          icon: const Icon(Icons.text_fields), label: const Text('Add text')),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(onPressed: _addSticker,
                          icon: const Icon(Icons.emoji_emotions_outlined), label: const Text('Add sticker')),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(onPressed: _chooseBorder,
                          icon: const Icon(Icons.crop_square_rounded), label: const Text('Border')),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: session.editorItems.isEmpty
                            ? null
                            : () => setState(() => session.editorItems.removeLast()),
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo last'),
                      ),
                      const SizedBox(height: 20),
                      const Card(
                        color: SkyeColors.mist,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                              'Tip: tap a sticker or text to select it. Drag to move '
                              'it, tap − / + to resize, or pinch with two fingers. '
                              'Border wraps the photos in one printed frame.'),
                        ),
                      ),
                    ],
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
/// A live thumbnail of a frame style. The real print-size artwork is rendered
/// and then scaled down, so the picker shows exactly what will be printed.
class _BorderPreview extends StatelessWidget {
  const _BorderPreview({required this.tier, required this.spec});

  final PricingTier tier;
  final PrintBorder spec;

  @override
  Widget build(BuildContext context) {
    final photos = switch (tier.layout) {
      LayoutType.single => const _PhotoStub(),
      LayoutType.grid => const Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _PhotoStub()),
                  SizedBox(width: kGridPhotoGutter),
                  Expanded(child: _PhotoStub()),
                ],
              ),
            ),
            SizedBox(height: kGridPhotoGutter),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _PhotoStub()),
                  SizedBox(width: kGridPhotoGutter),
                  Expanded(child: _PhotoStub()),
                ],
              ),
            ),
          ],
        ),
      LayoutType.strip => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < 3; index++) ...[
              const AspectRatio(aspectRatio: kStripPhotoAspect, child: _PhotoStub()),
              if (index != 2) const SizedBox(height: kStripPhotoGutter),
            ],
          ],
        ),
    };

    final framed = PrintBorderFrame(border: spec.id, child: photos);
    return FittedBox(
      fit: BoxFit.contain,
      child: tier.layout == LayoutType.strip
          ? SizedBox(width: _printWidth, child: framed)
          : SizedBox(width: _printWidth, height: _standardHeight, child: framed),
    );
  }
}

/// The fixed print geometry the composition uses, reused by the thumbnails so
/// an inset of, say, 96 px still lands in the same place as it will on paper.
const double _printWidth = 576;
const double _standardHeight = 821;

/// A grey stand-in for a photo in a frame thumbnail.
class _PhotoStub extends StatelessWidget {
  const _PhotoStub();

  @override
  Widget build(BuildContext context) => const ColoredBox(color: SkyeColors.mist);
}
