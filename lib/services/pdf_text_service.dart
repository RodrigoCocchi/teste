import 'dart:io';
import 'dart:isolate';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

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
  const HymnDetection(this.pages, this.pageCount, this.pagesWithText);
  final Map<int, int> pages; // número do hino → página (1-based)
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
                    w.bounds.height),
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

/// Procura o número do hino no topo de cada página ("Hino 12", "12", "Nº 12").
/// Aceita apenas números em ordem crescente para evitar falsos positivos.
HymnDetection detectHymnPages(List<List<String>> pages) {
  final found = <int, int>{};
  var withText = 0;
  var last = 0;
  final pattern = RegExp(r'^(?:hino\s*|n[º°o.]\s*)?(\d{1,3})(?:\s*[-–.]|\s*$|\s+[A-ZÀ-Ú])',
      caseSensitive: false);
  for (var p = 0; p < pages.length; p++) {
    final lines = pages[p];
    if (lines.isNotEmpty) withText++;
    for (final line in lines.take(3)) {
      final m = pattern.firstMatch(line.trim());
      if (m == null) continue;
      final n = int.parse(m[1]!);
      if (n == last + 1 || (n > last && n <= last + 3 && n <= 480)) {
        found[n] = p + 1;
        last = n;
        break;
      }
    }
  }
  return HymnDetection(found, pages.length, withText);
}
