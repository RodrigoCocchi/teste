// Verificação online (roda no CI): baixa os documentos das fontes indicadas
// com o mesmo código do app, valida que são PDFs e testa a estruturação da
// Bíblia. Imprime só um resumo; os arquivos são apagados ao final.
//
//   ONLINE_CHECK=1 flutter test tool/source_check_test.dart
import 'dart:io';

import 'package:biblia_hinos_ccb/data/bible_books.dart';
import 'package:biblia_hinos_ccb/services/documents.dart';
import 'package:biblia_hinos_ccb/services/pdf_text_service.dart';
import 'package:biblia_hinos_ccb/services/source_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

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
      final from = await d.download(officialSources[kind]!, dest,
          prefer: kind == DocKind.hymnalOrgao ? 'orgao' : null);
      d.close();
      final size = await File(dest).length();
      stdout.writeln('[fonte] ${kind.label}: OK, ${(size / 1048576).toStringAsFixed(1)} MB, origem ${Uri.parse(from).host}');
      if (kind == DocKind.bible) {
        final r = await PdfTextService.parseBible(dest);
        stdout.writeln('[biblia] ${r.summary().replaceAll('\n', ' | ')}');
        final missingBooks = <String>{for (final k in r.missingChapters) bookById(k ~/ 1000).abbrev};
        stdout.writeln('[biblia] livros com capítulos ausentes: ${missingBooks.join(' ')}');
        for (final key in [1001, 43003, 19023, 66022]) {
          final vs = r.verses.where((v) => v.book * 1000 + v.chapter == key).toList();
          stdout.writeln('[biblia] ${bookById(key ~/ 1000).abbrev} ${key % 1000}: ${vs.length} versículos'
              '${vs.isEmpty ? '' : '; v1 com ${vs.first.text.length} caracteres'}');
        }
      } else {
        final h = await PdfTextService.detectHymns(dest);
        stdout.writeln('[hinario] ${kind.key}: ${h.pageCount} páginas, ${h.pagesWithText} com texto, '
            '${h.pages.length} hinos detectados automaticamente');
      }
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
