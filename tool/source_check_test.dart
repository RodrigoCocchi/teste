// Verificação online (roda no CI): baixa os documentos das fontes indicadas
// com o mesmo código do app, valida que são PDFs e testa a estruturação da
// Bíblia. Imprime só resumos e a ESTRUTURA das linhas (palavras mascaradas);
// os arquivos são apagados ao final.
//
//   ONLINE_CHECK=1 flutter test tool/source_check_test.dart
import 'dart:io';

import 'package:biblia_hinos_ccb/data/bible_books.dart';
import 'package:biblia_hinos_ccb/services/bible_parser.dart';
import 'package:biblia_hinos_ccb/services/documents.dart';
import 'package:biblia_hinos_ccb/services/pdf_text_service.dart';
import 'package:biblia_hinos_ccb/services/source_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mascara palavras em minúsculas (mantém números, pontuação e palavras em
/// MAIÚSCULAS), para ver o layout sem reproduzir o texto.
String mask(String line) => line.replaceAllMapped(
    RegExp(r'[A-Za-zÀ-ÿ]+'),
    (m) => m[0] == m[0]!.toUpperCase() && m[0]!.length > 1 ? m[0]! : 'x' * m[0]!.length);

void log(String s) => stdout.writeln('[diag] $s');

void main() {
  final enabled = Platform.environment['ONLINE_CHECK'] == '1';
  late Directory dir;
  setUpAll(() async => dir = await Directory.systemTemp.createTemp('bh_src'));
  tearDownAll(() async => dir.delete(recursive: true));

  for (final kind in DocKind.values) {
    test('fonte: ${kind.label}', () async {
      if (!enabled) {
        markTestSkipped('ONLINE_CHECK=1 não definido');
        return;
      }
      final d = SourceDownloader();
      final dest = '${dir.path}/${kind.key}.pdf';
      String from;
      try {
        from = await d.download(officialSources[kind]!, dest,
            prefer: kind == DocKind.hymnalOrgao ? 'orgao' : null,
            onProgress: (p) {
              if (!p.message.startsWith('Baixando:')) log('${kind.key}: ${p.message}');
            });
      } on Object catch (e) {
        log('${kind.key}: FALHA no download: $e');
        rethrow;
      } finally {
        d.close();
      }
      final size = await File(dest).length();
      log('${kind.key}: OK ${(size / 1048576).toStringAsFixed(1)} MB de ${Uri.parse(from).host}');
      final sw = Stopwatch()..start();
      final pages = PdfTextService.extractPageLines(dest);
      log('${kind.key}: ${pages.length} páginas extraídas em ${sw.elapsed.inSeconds}s; '
          '${pages.where((p) => p.isNotEmpty).length} com texto');
      if (kind == DocKind.bible) {
        final r = parseBibleText(pages);
        log('biblia: ${r.summary().replaceAll('\n', ' | ')}');
        final perBook = <int, int>{};
        for (final k in r.parsedChapters) {
          perBook[k ~/ 1000] = (perBook[k ~/ 1000] ?? 0) + 1;
        }
        log('biblia: incompletos: ${bibleBooks.where((b) => (perBook[b.id] ?? 0) != b.chapters).map((b) => '${b.abbrev}=${perBook[b.id] ?? 0}/${b.chapters}').join(' ')}');
        log('biblia: suspeitos: ${r.suspectChapters.map((k) => '${bookById(k ~/ 1000).abbrev}${k % 1000}').join(' ')}');
        final lastPage = r.chapterPages.values.fold<int>(0, (a, b) => b > a ? b : a);
        log('biblia: último capítulo reconhecido na página $lastPage');
        final firstPage = r.chapterPages[1001] ?? 1;
        final gn2 = r.chapterPages[1002] ?? firstPage;
        for (final p in {lastPage, lastPage + 1}) {
          if (p < 1 || p > pages.length) continue;
          log('--- página $p (${pages[p - 1].length} linhas) ---');
          for (final l in pages[p - 1].take(45)) {
            log('  | ${mask(l)}');
          }
        }
        final last = r.verses.isEmpty ? null : r.verses.last;
        if (last != null) {
          log('biblia: último versículo ${bookById(last.book).abbrev} ${last.chapter}:${last.verse} '
              '(${last.text.length} caracteres)');
        }
      } else {
        final h = detectHymnPages(pages);
        log('${kind.key}: ${h.pages.length} hinos detectados automaticamente');
        log('${kind.key}: primeiros detectados: ${h.pages.entries.take(12).map((e) => '${e.key}→p${e.value}').join(' ')}');
        for (final p in [9, 10, 11, 12, 50, 51]) {
          if (p > pages.length) continue;
          log('--- página $p ---');
          for (final l in pages[p - 1].take(5)) {
            log('  | ${mask(l)}');
          }
        }
      }
    }, timeout: const Timeout(Duration(minutes: 40)));
  }
}
