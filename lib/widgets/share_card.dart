import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme.dart';
import 'common.dart';

/// Bloco do cartão: título opcional, linhas (rótulo, valor) e subtotal.
class ShareSection {
  const ShareSection({this.title, this.rows = const [], this.total});
  final String? title;
  final List<(String, String)> rows;
  final String? total;
}

/// Conteúdo de um cartão para compartilhar (imagem bonita + texto para WhatsApp).
class ShareCardData {
  const ShareCardData({
    required this.kicker,
    required this.title,
    this.subtitle,
    this.icon = Icons.event,
    this.sections = const [],
    this.highlight,
    this.footer,
  });
  final String kicker; // ex.: ENSAIO MUSICAL
  final String title; // ex.: nome da igreja
  final String? subtitle; // ex.: data e hora
  final IconData icon;
  final List<ShareSection> sections;
  final (String, String)? highlight; // ex.: ('Total', '84')
  final String? footer;

  /// Texto formatado para WhatsApp (*negrito*).
  String get text {
    final b = StringBuffer('*${kicker.toUpperCase()}*\n*$title*\n');
    if (subtitle != null) b.writeln(subtitle);
    for (final s in sections) {
      b.writeln();
      if (s.title != null) b.writeln('*${s.title}*');
      for (final (k, v) in s.rows) {
        b.writeln(v.isEmpty ? k : '$k: $v');
      }
      if (s.total != null) b.writeln('_Subtotal: ${s.total}_');
    }
    if (highlight != null) b.writeln('\n*${highlight!.$1}: ${highlight!.$2}*');
    if (footer != null) b.writeln('\n$footer');
    return b.toString().trim();
  }
}

/// O cartão desenhado (usado na tela e na imagem).
class ShareCard extends StatelessWidget {
  const ShareCard(this.data, {super.key});
  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    const navy = AppColors.navy, gold = AppColors.gold;
    return Container(
      width: 420,
      decoration: const BoxDecoration(color: Color(0xFFF7F2E7)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [navy, Color(0xFF1C3D6E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: gold.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(data.icon, color: gold, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data.kicker.toUpperCase(),
                    style: const TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(data.title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                if (data.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(data.subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final s in data.sections) ...[
              if (s.title != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(s.title!,
                          style: const TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    if (s.total != null)
                      Text(s.total!, style: const TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                ),
              for (final (k, v) in s.rows)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x22000000)))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(k, style: const TextStyle(color: Color(0xFF333333), fontSize: 14))),
                    if (v.isNotEmpty)
                      Text(v, style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ],
          ]),
        ),
        if (data.highlight != null)
          Container(
            margin: const EdgeInsets.fromLTRB(22, 6, 22, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                child: Text(data.highlight!.$1,
                    style: const TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 17)),
              ),
              Text(data.highlight!.$2, style: const TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 22)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
          child: Text(data.footer ?? '', style: const TextStyle(color: Color(0xFF777777), fontSize: 11)),
        ),
      ]),
    );
  }
}

/// Tela com o cartão e os botões de compartilhar (imagem ou texto).
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.data, this.title = 'Compartilhar'});
  final ShareCardData data;
  final String title;
  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final f = File(p.join((await getTemporaryDirectory()).path, 'cartao_${DateTime.now().millisecondsSinceEpoch}.png'));
      await f.writeAsBytes(png!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'image/png')]));
    } on Object {
      if (mounted) showSnack(context, 'Não foi possível gerar a imagem.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Center(
            child: FittedBox(
              child: RepaintBoundary(key: _key, child: ShareCard(widget.data)),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image_outlined),
            label: const Text('Compartilhar imagem'),
            onPressed: _busy ? null : _shareImage,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.text_snippet_outlined),
            label: const Text('Compartilhar como texto'),
            onPressed: () => SharePlus.instance.share(ShareParams(text: widget.data.text)),
          ),
        ]),
      );
}

const List<String> monthNames = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];
const List<String> weekdayLong = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];

String two(int n) => n.toString().padLeft(2, '0');

/// "quinta-feira, 22 de outubro de 2026"
String longDate(DateTime d) => '${weekdayLong[d.weekday - 1]}, ${d.day} de ${monthNames[d.month - 1]} de ${d.year}';

/// "22/10 · 19:30"
String shortDateTime(DateTime d) => '${two(d.day)}/${two(d.month)} · ${two(d.hour)}:${two(d.minute)}';

String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
