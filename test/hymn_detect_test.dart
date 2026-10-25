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

  test('coros depois do hino 480, a partir do título "Coros"', () {
    final pages = <List<String>>[
      for (var n = 1; n <= 480; n++) ['$n - Hino $n', '1. primeira estrofe', '2. segunda estrofe'],
      ['ÍNDICE'],
      ['1 - número no índice'],
      ['Coros', '1 - Aleluia! Aleluia!', 'letra', '2 - Segundo coro', '3. não é coro'],
      ['3 - Terceiro coro', '4 - Quarto', '5 - Quinto', '6 - Sexto'],
    ];
    final r = detectHymnPages(pages);
    expect(r.pages[480], 480);
    expect([for (var c = 481; c <= 486; c++) r.pages[c]], [483, 483, 484, 484, 484, 484]);
    expect(r.titles[481], 'Aleluia! Aleluia!');
  });
}
