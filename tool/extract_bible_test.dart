// Extrai e estrutura a Bíblia de um PDF no computador, com o mesmo código do
// aplicativo, gerando JSON (importável no app) e um relatório:
//
//   BIBLE_PDF=/caminho/Biblia-ARC-1969.pdf flutter test tool/extract_bible_test.dart
//
// Saída: build/biblia_estruturada.json e build/biblia_relatorio.txt
import 'dart:convert';
import 'dart:io';

import 'package:biblia_hinos_ccb/data/bible_books.dart';
import 'package:biblia_hinos_ccb/services/pdf_text_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final path = Platform.environment['BIBLE_PDF'];
  test('extrair Bíblia do PDF', () async {
    if (path == null) {
      markTestSkipped('Defina BIBLE_PDF com o caminho do PDF.');
      return;
    }
    final r = await PdfTextService.parseBible(path, onProgress: (p) {
      if (p.page % 100 == 0) stdout.writeln('página ${p.page}/${p.pages}');
    });
    await Directory('build').create(recursive: true);
    await File('build/biblia_estruturada.json').writeAsString(jsonEncode({
      'source': 'PDF: ${path.split('/').last}',
      'verses': [for (final v in r.verses) {'b': v.book, 'c': v.chapter, 'v': v.verse, 't': v.text}],
    }));
    final report = StringBuffer(r.summary())
      ..writeln('Capítulos a conferir:')
      ..writeAll(r.suspectChapters.map((k) => '  ${bookById(k ~/ 1000).name} ${k % 1000}\n'));
    await File('build/biblia_relatorio.txt').writeAsString(report.toString());
    stdout.writeln(report);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
