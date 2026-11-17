import 'dart:io';
import 'dart:isolate';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../data/hymn_repository.dart';
import 'bible_parser.dart';

/// Mensagens de progresso enviadas pelo isolate de extração.
class ExtractProgress {
  const ExtractProgress(this.page, this.pages);
  final int page;
  final int pages;
}

class _Job {
  _Job(this.port, this.path, this.mode);
  final SendPort port;
  final String path;
  final String mode; // 'bible' | 'hymns'
}

/// Resultado da detecção automática de páginas dos hinos.
class HymnDetection {
  const HymnDetection(this.pages, this.pageCount, this.pagesWithText,
      [this.titles = const {}, this.texts = const {}]);
  final Map<int, int> pages; // número do hino → página (1-based)
  final Map<int, String> titles; // título impresso ao lado do número
  final Map<int, String> texts; // texto da página do hino (útil no hinário só com a letra)
  final int pageCount;
  final int pagesWithText;
}

/// Extrai o texto do PDF fora da thread da interface (isolate), página a
/// página, para não travar o aplicativo.
class PdfTextService {
  static Future<BibleParseResult> parseBible(String path,
          {void Function(ExtractProgress)? onProgress}) =>
      _run<BibleParseResult>(path, 'bible', onProgress);

  static Future<HymnDetection> detectHymns(String path,
          {void Function(ExtractProgress)? onProgress}) =>
      _run<HymnDetection>(path, 'hymns', onProgress);

  static Future<T> _run<T>(
      String path, String mode, void Function(ExtractProgress)? onProgress) async {
    final port = ReceivePort();
    final errors = ReceivePort();
    final isolate = await Isolate.spawn(_entry, _Job(port.sendPort, path, mode),
        onError: errors.sendPort);
    try {
      final result = await Future.any<Object?>([
        port.firstWhere((m) {
          if (m is ExtractProgress) {
            onProgress?.call(m);
            return false;
          }
          return true;
        }),
        errors.first.then((e) => throw Exception('Falha na extração: ${(e as List).first}')),
      ]);
      if (result is String) throw Exception(result);
      return result as T;
    } finally {
      port.close();
      errors.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  /// Linhas de cada página em ordem de leitura (usado também em diagnóstico).
  static List<List<String>> extractPageLines(String path,
      {void Function(int page, int pages)? onPage, int? maxPages}) {
    final doc = sf.PdfDocument(inputBytes: File(path).readAsBytesSync());
    final extractor = sf.PdfTextExtractor(doc);
    final count = maxPages == null ? doc.pages.count : maxPages.clamp(0, doc.pages.count);
    final pages = <List<String>>[];
    for (var i = 0; i < count; i++) {
      List<String> lines;
      try {
        final textLines = extractor.extractTextLines(startPageIndex: i, endPageIndex: i);
        final words = <WordBox>[
          for (final l in textLines)
            for (final w in l.wordCollection)
              if (w.text.trim().isNotEmpty)
                WordBox(w.text.trim(), w.bounds.left, w.bounds.top, w.bounds.width,
                    w.bounds.height, w.fontSize),
        ];
        lines = orderPageLines(words, doc.pages[i].size.width);
      } on Object {
        lines = const [];
      }
      pages.add(lines);
      onPage?.call(i + 1, count);
    }
    doc.dispose();
    return pages;
  }

  static void _entry(_Job job) {
    try {
      final pages = extractPageLines(job.path, onPage: (i, count) {
        if (i % 5 == 0 || i == count) job.port.send(ExtractProgress(i, count));
      });
      if (job.mode == 'bible') {
        job.port.send(parseBibleText(pages));
      } else {
        job.port.send(detectHymnPages(pages));
      }
    } on Object catch (e) {
      job.port.send('Não foi possível ler o PDF: $e');
    }
  }
}

final RegExp _titleAfterNumber =
    RegExp(r'^(?:hino\s*|n[º°o.]\s*)?\d{1,3}\s*[-–.]?\s*(.*)$', caseSensitive: false);

/// Procura o número do hino no topo de cada página ("Hino 12", "12", "Nº 12").
/// Aceita apenas números em ordem crescente para evitar falsos positivos.
HymnDetection detectHymnPages(List<List<String>> pages) {
  final found = <int, int>{};
  final titles = <int, String>{};
  final starts = <int, (int, int)>{}; // hino → (página, linha) do cabeçalho
  var withText = 0;
  var last = 0;
  final pattern = RegExp(r'^(?:hino\s*|n[º°o.]\s*)?(\d{1,3})(?:\s*[-–.]|\s*$|\s+[A-ZÀ-Ú])',
      caseSensitive: false);
  for (var p = 0; p < pages.length; p++) {
    final lines = pages[p];
    if (lines.isNotEmpty) withText++;
    for (final (li, raw) in lines.take(3).indexed) {
      final line = raw.replaceAll(smallMark, '');
      final m = pattern.firstMatch(line.trim());
      if (m == null) continue;
      final n = int.parse(m[1]!);
      if (n == last + 1 || (n > last && n <= last + 10 && n <= 480)) {
        found[n] = p + 1;
        starts[n] = (p, li);
        final title = (_titleAfterNumber.firstMatch(line.trim())?[1] ?? '')
            .replaceAll(smallMark, '')
            .trim();
        if (title.length >= 3 && RegExp(r'[A-Za-zÀ-ÿ]{3}').hasMatch(title)) titles[n] = title;
        last = n;
        break;
      }
    }
  }
  _detectChoirs(pages, found, titles, starts);
  return HymnDetection(found, pages.length, withText, titles, hymnTexts(pages, starts));
}

final RegExp _sectionEnd = RegExp(r'^(?:í|i)ndice\b|^coros?$', caseSensitive: false);

/// Texto de cada hino: do cabeçalho até o próximo hino (no máximo 2 páginas),
/// parando em títulos de seção como "Índice" ou "Coros".
Map<int, String> hymnTexts(List<List<String>> pages, Map<int, (int, int)> starts) {
  final order = starts.entries.toList()
    ..sort((a, b) => a.value.$1 != b.value.$1 ? a.value.$1 - b.value.$1 : a.value.$2 - b.value.$2);
  final out = <int, String>{};
  for (var i = 0; i < order.length; i++) {
    final (p0, l0) = order[i].value;
    final next = i + 1 < order.length ? order[i + 1].value : null;
    final lines = <String>[];
    for (var p = p0; p < pages.length && p <= p0 + 1; p++) {
      final page = pages[p];
      final to = next != null && next.$1 == p ? next.$2 : page.length;
      var stop = false;
      for (var l = p == p0 ? l0 + 1 : 0; l < to; l++) {
        final t = page[l].replaceAll(smallMark, '').trim();
        if (_sectionEnd.hasMatch(t)) {
          stop = true;
          break;
        }
        if (t.isNotEmpty && !RegExp(r'^\d{1,3}$').hasMatch(t)) lines.add(t); // sem número de página
      }
      if (stop || (next != null && next.$1 == p)) break;
    }
    if (lines.isNotEmpty) out[order[i].key] = lines.join('\n');
  }
  return out;
}

final RegExp _choirHeader = RegExp(r'^coros?$', caseSensitive: false);
final RegExp _choirLine = RegExp(r'^(?:coro\s*)?(\d)\s*[-–]\s*(.*)$', caseSensitive: false);

/// Coros (481–486): depois do último hino, procura a página com o título
/// "Coros" e os números 1 a 6 em sequência a partir dela.
void _detectChoirs(
    List<List<String>> pages, Map<int, int> found, Map<int, String> titles, Map<int, (int, int)> starts) {
  if (!found.containsKey(Hymns.hymnCount)) return;
  final start = pages.indexWhere(
      (lines) => lines.take(3).any((l) => _choirHeader.hasMatch(l.replaceAll(smallMark, '').trim())),
      found[Hymns.hymnCount]!);
  if (start < 0) return;
  var next = 1;
  for (var p = start; p < pages.length && next <= Hymns.choirCount; p++) {
    for (final (li, raw) in pages[p].indexed) {
      final m = _choirLine.firstMatch(raw.replaceAll(smallMark, '').trim());
      if (m == null || int.parse(m[1]!) != next) continue;
      found[Hymns.hymnCount + next] = p + 1;
      starts[Hymns.hymnCount + next] = (p, li);
      final title = m[2]!.trim();
      if (title.length >= 3) titles[Hymns.hymnCount + next] = title;
      next++;
    }
  }
}
