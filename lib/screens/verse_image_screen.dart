import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Estilo do cartão do versículo.
class VerseCardStyle {
  const VerseCardStyle(this.name, this.colors, this.text, this.accent);
  final String name;
  final List<Color> colors;
  final Color text;
  final Color accent;
}

const List<VerseCardStyle> verseCardStyles = [
  VerseCardStyle('Azul', [Color(0xFF0B2545), Color(0xFF1C3D6E)], Colors.white, AppColors.gold),
  VerseCardStyle('Pergaminho', [Color(0xFFF7F0DD), Color(0xFFE9DCB9)], Color(0xFF2B2416), Color(0xFF8C6D1F)),
  VerseCardStyle('Dourado', [Color(0xFFB8902F), Color(0xFFE2C46B)], Color(0xFF1B1405), Color(0xFF0B2545)),
  VerseCardStyle('Noite', [Color(0xFF111111), Color(0xFF2E2E2E)], Color(0xFFF2F2F2), AppColors.gold),
];

/// Gera uma imagem do versículo para compartilhar (WhatsApp, status…).
class VerseImageScreen extends StatefulWidget {
  const VerseImageScreen({super.key, required this.text, required this.reference});
  final String text;
  final String reference; // ex.: João 3:16 (ARC)
  @override
  State<VerseImageScreen> createState() => _VerseImageScreenState();
}

class _VerseImageScreenState extends State<VerseImageScreen> {
  final _key = GlobalKey();
  int _style = 0;
  bool _square = true;
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File(p.join(dir.path, 'versiculo_${DateTime.now().millisecondsSinceEpoch}.png'));
      await f.writeAsBytes(png!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'image/png')], text: widget.reference));
    } on Object {
      if (mounted) showSnack(context, 'Não foi possível gerar a imagem.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = verseCardStyles[_style];
    final long = widget.text.length;
    final fontSize = long > 500 ? 15.0 : long > 300 ? 18.0 : long > 150 ? 22.0 : 26.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Versículo em imagem')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: RepaintBoundary(
            key: _key,
            child: AspectRatio(
              aspectRatio: _square ? 1 : 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: s.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.format_quote, color: s.accent, size: 36),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: s.text, fontSize: fontSize, height: 1.45, fontFamily: 'serif'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(width: 48, height: 2, color: s.accent),
                  const SizedBox(height: 10),
                  Text(widget.reference,
                      style: TextStyle(color: s.accent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < verseCardStyles.length; i++)
            ChoiceChip(
              avatar: CircleAvatar(backgroundColor: verseCardStyles[i].colors.first),
              label: Text(verseCardStyles[i].name),
              selected: i == _style,
              onSelected: (_) => setState(() => _style = i),
            ),
        ]),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, icon: Icon(Icons.crop_square), label: Text('Quadrado')),
            ButtonSegment(value: false, icon: Icon(Icons.crop_portrait), label: Text('Status')),
          ],
          selected: {_square},
          onSelectionChanged: (v) => setState(() => _square = v.first),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.share),
          label: const Text('Compartilhar imagem'),
          onPressed: _busy ? null : _share,
        ),
      ]),
    );
  }
}
