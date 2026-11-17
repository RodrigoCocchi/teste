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

  test('extrai a letra de cada hino até o próximo, sem o índice nem número de página', () {
    final pages = <List<String>>[
      ['1 - Cristo meu Mestre...', '1. Cristo meu Mestre e meu Senhor,', 'Eu Te adoro', '2. Mestre divino', '3'],
      ['2 - Segundo', '1. Primeira estrofe', 'continua'],
      ['segunda página do hino 2'],
      ['3 - Terceiro', 'letra do três'],
      ['Índice', '122 Hino do índice'],
    ];
    final r = detectHymnPages(pages);
    expect(r.texts[1], '1. Cristo meu Mestre e meu Senhor,\nEu Te adoro\n2. Mestre divino');
    expect(r.texts[2], '1. Primeira estrofe\ncontinua\nsegunda página do hino 2');
    expect(r.texts[3], 'letra do três');
  });

  test('letra dos coros na mesma página', () {
    final pages = <List<String>>[
      for (var n = 1; n <= 480; n++) ['$n - Hino $n', 'letra $n'],
      ['Coros', '1 - Aleluia!', 'Aleluia! Aleluia!', '2 - Segundo coro', 'letra do segundo'],
    ];
    final r = detectHymnPages(pages);
    expect(r.texts[481], 'Aleluia! Aleluia!');
    expect(r.texts[482], 'letra do segundo');
    expect(r.texts[480], 'letra 480');
  });
}
