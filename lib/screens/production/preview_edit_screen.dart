import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app.dart';
import '../../models/editor_item.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/kiosk_shell.dart';
import '../../widgets/photo_composition.dart';
import '../../widgets/screen_heading.dart';
import 'printing_screen.dart';

class PreviewEditScreen extends StatefulWidget {
  const PreviewEditScreen({super.key});

  @override
  State<PreviewEditScreen> createState() => _PreviewEditScreenState();
}

class _PreviewEditScreenState extends State<PreviewEditScreen> {
  final _compositionKey = GlobalKey();
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
    const stickers = [
      '🥳', '🎉', '🎈', '🎂', '✨', '🩷', '🌟', '🌸',
      '🌼', '🌻', '🍀', '🌈', '☁️', '💛', '💙', '🫶',
      '😍', '🥰', '😎', '🤪', '🥳', '🐻', '🐰', '🐱',
      '☕', '🧁', '🍩', '🍓', '🍒', '🍦', '🍭', '📸',
    ];
    final sticker = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Text('Pick a sticker', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 8,
                  children: [
                    for (final value in stickers)
                      InkWell(
                        onTap: () => Navigator.pop(context, value),
                        borderRadius: BorderRadius.circular(12),
                        child: Center(child: Text(value, style: const TextStyle(fontSize: 38))),
                      ),
                  ],
                ),
              ),
            ],
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

  Future<void> _exportAndPrint() async {
    final app = AppScope.of(context, listen: false);
    final session = app.session!;
    setState(() => _exporting = true);
    try {
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
    final session = AppScope.of(context).session!;
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
              onPressed: session.copies < 2 ? () => setState(() => session.copies++) : null,
              icon: const Icon(Icons.add),
            ),
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
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10))],
                    ),
                    child: RepaintBoundary(
                      key: _compositionKey,
                      child: PhotoComposition(session: session, onChanged: () => setState(() {})),
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
                      child: Text('Tip: use one finger to move an item and two fingers to resize it.'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
