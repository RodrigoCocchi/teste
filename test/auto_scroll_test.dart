import 'package:biblia_hinos_ccb/data/hymn_repository.dart';
import 'package:biblia_hinos_ccb/services/auto_scroll.dart';
import 'package:biblia_hinos_ccb/services/documents.dart';
import 'package:biblia_hinos_ccb/services/source_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('níveis de velocidade da rolagem automática', () {
    expect(autoScrollLevel(autoScrollSpeeds.first), 1);
    expect(autoScrollLevel(30), 5);
    expect(autoScrollLevel(31), 5);
    expect(autoScrollStep(30, 1), 40);
    expect(autoScrollStep(30, -1), 22);
    expect(autoScrollStep(autoScrollSpeeds.last, 1), autoScrollSpeeds.last);
    expect(autoScrollStep(autoScrollSpeeds.first, -1), autoScrollSpeeds.first);
  });

  test('hinário só canto é um terceiro documento do hinário', () {
    expect(Hymns.docs, ['do', 'orgao', 'canto']);
    expect(DocKind.hymnal('canto'), DocKind.hymnalCanto);
    expect(DocKind.hymnal('orgao'), DocKind.hymnalOrgao);
    expect(DocKind.hymnal('do'), DocKind.hymnalDo);
    expect(Hymns.docLabel('canto'), 'Hinário só canto');
    expect(officialSources[DocKind.hymnalCanto], contains('drive.google.com'));
    // O link do Drive vira o endereço de download direto.
    final links = extractPdfLinks('<a href="${officialSources[DocKind.hymnalCanto]}">x</a>', Uri.parse('https://example.org/'));
    expect(links.map((u) => u.toString()), contains(contains('1C5lUn5MXrSg20HrfgoQw5cppFiVGhpMQ')));
  });
}
