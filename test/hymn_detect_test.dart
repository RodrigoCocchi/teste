import 'package:biblia_hinos_ccb/services/pdf_text_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detecta número e título no topo das páginas, em ordem', () {
    final pages = <List<String>>[
      ['ÍNDICE', '12 Título errado do índice'],
      ['EM BRANCO'],
      ['1 Título de teste um...', '( = 80-100)'],
      ['2 Outro título de teste'],
      ['2 continuação da partitura'],
      ['3 Terceiro título'],
      ['250 número fora de ordem'],
      ['4 Quarto'],
    ];
    final r = detectHymnPages(pages);
    expect(r.pages, {1: 3, 2: 4, 3: 6, 4: 8});
    expect(r.titles[1], 'Título de teste um...');
    expect(r.titles[3], 'Terceiro título');
  });
}
