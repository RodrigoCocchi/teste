import 'dart:math';

import 'package:biblia_hinos_ccb/data/bible_books.dart';
import 'package:biblia_hinos_ccb/services/bible_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texto sintético de teste (NÃO é texto bíblico): permite conferir que o
/// parser reconstrói exatamente livro/capítulo/versículo.
String fakeVerse(int b, int c, int v) =>
    'Linha de teste com palavras ${v.isEven ? 'pares' : 'ímpares'}, e o '
    'SENHOR disse-lhe: fim. marca${'x' * (v % 7)} livro${'b' * (b % 5)} '
    'cap${'c' * (c % 4)}.';

/// Monta páginas simulando um PDF: títulos de livro, capítulos como
/// capitular (número isolado) ou "CAPÍTULO n", cabeçalhos e números de página.
List<List<String>> buildPages({required bool dropCap, int seed = 1}) {
  final rnd = Random(seed);
  final lines = <String>['BÍBLIA SAGRADA', 'Índice', 'Gênesis 1', 'Êxodo 45'];
  for (final b in bibleBooks) {
    lines.add('LIVRO DE ${b.name.toUpperCase()}');
    for (var c = 1; c <= b.chapters; c++) {
      final verses = 2 + rnd.nextInt(30);
      if (dropCap) {
        lines.add('$c');
      } else {
        lines.add(b.id == 19 ? 'SALMO $c' : 'CAPÍTULO $c');
      }
      for (var v = 1; v <= verses; v++) {
        final text = b.id == 1 && c == 1 && v == 1
            ? 'No princípio linha inicial de teste.'
            : fakeVerse(b.id, c, v);
        final prefix = dropCap && v == 1 ? '' : '$v ';
        // quebra o versículo em duas linhas, às vezes com hifenização
        final cut = text.indexOf(' ', text.length ~/ 2);
        lines.add('$prefix${text.substring(0, cut)}');
        lines.add(text.substring(cut + 1));
      }
    }
  }
  lines.add('Amém. APÊNDICE MAPAS');
  final pages = <List<String>>[];
  for (var i = 0; i < lines.length; i += 40) {
    final page = pages.length + 1;
    pages.add([
      'GÊNESIS ${page % 50 + 1}',
      ...lines.sublist(i, min(i + 40, lines.length)),
      '${page + 2}',
    ]);
  }
  return pages;
}

Map<int, int> expectedVerseCounts({required int seed}) {
  final rnd = Random(seed);
  final map = <int, int>{};
  for (final b in bibleBooks) {
    for (var c = 1; c <= b.chapters; c++) {
      map[b.id * 1000 + c] = 2 + rnd.nextInt(30);
    }
  }
  return map;
}

void main() {
  for (final dropCap in [false, true]) {
    test('estrutura os 66 livros (capitular=$dropCap)', () {
      final result = parseBibleText(buildPages(dropCap: dropCap, seed: 7));
      expect(result.missingChapters, isEmpty, reason: result.summary());
      final expected = expectedVerseCounts(seed: 7);
      final counts = <int, int>{};
      for (final v in result.verses) {
        counts[v.book * 1000 + v.chapter] = v.verse;
      }
      expect(counts, expected);
      expect(result.verses.length, expected.values.reduce((a, b) => a + b));
      final sample = result.verses.firstWhere(
          (v) => v.book == 43 && v.chapter == 3 && v.verse == 2);
      expect(sample.text, fakeVerse(43, 3, 2));
      expect(result.verses.first.text, 'No princípio linha inicial de teste.');
      expect(result.suspectChapters, isEmpty);
    });
  }

  test('texto sem estrutura não gera versículos inventados', () {
    final result = parseBibleText([
      ['Página sem numeração alguma', 'apenas texto corrido'],
    ]);
    expect(result.verses, isEmpty);
    expect(result.missingChapters.length, totalBibleChapters);
  });

  test('ordena duas colunas', () {
    const w = 600.0;
    final words = <WordBox>[
      const WordBox('A1', 50, 100, 40, 10),
      const WordBox('B1', 350, 100, 40, 10),
      const WordBox('A2', 50, 120, 40, 10),
      const WordBox('B2', 350, 120, 40, 10),
      const WordBox('A3', 100, 140, 40, 10),
      const WordBox('B3', 400, 140, 40, 10),
    ];
    expect(orderPageLines(words, w), ['A1', 'A2', 'A3', 'B1', 'B2', 'B3']);
  });

  test('uma coluna mantém linhas inteiras', () {
    final words = <WordBox>[
      for (var line = 0; line < 6; line++)
        for (var x = 50.0 + (line * 23) % 60; x < 520; x += 70)
          WordBox('p$line', x, 100.0 + line * 14, 55, 10),
    ];
    final lines = orderPageLines(words, 600);
    expect(lines.length, 6);
    expect(lines.first.split(' ').every((w) => w == 'p0'), isTrue);
  });

  test('junta letras soltas e marca números pequenos (notas)', () {
    // Cada letra como uma "palavra", como no PDF da ARC 1969.
    final words = <WordBox>[];
    var x = 50.0;
    void word(String w, {double size = 10, double gapAfter = 3}) {
      for (final ch in w.split('')) {
        words.add(WordBox(ch, x, 100, 5, 10, size));
        x += 5;
      }
      x += gapAfter;
    }

    word('17', gapAfter: 3);
    word('Disse');
    word('ele', gapAfter: 0.2);
    word('3', size: 6);
    word('fim.');
    final line = orderPageLines(words, 600).single;
    expect(line, '17 Disse ele${smallMark}3 fim.');
  });

  test('ignora chamadas de nota e linhas de referências cruzadas', () {
    final pages = <List<String>>[
      ['GÊNESIS', '1', 'No princípio texto de teste${smallMark}1 um.',
        '2 Segundo texto de teste.', '1 1.1 Jo 1.1', '3 Terceiro${smallMark}2 texto.'],
    ];
    final r = parseBibleText(pages);
    final gn1 = r.verses.where((v) => v.book == 1 && v.chapter == 1).toList();
    expect(gn1.map((v) => v.verse), [1, 2, 3]);
    expect(gn1[0].text, 'No princípio texto de teste um.');
    expect(gn1[2].text, 'Terceiro texto.');
  });

  test('layout ARC: versículo em fonte pequena, "Livro N", títulos e notas', () {
    const m = smallMark;
    final pages = <List<String>>[
      ['Gênesis 1', 'A criação', '${m}1 No princípio texto de teste um.',
        '${m}2 Segundo de teste,', 'continua aqui.${m}1', '${m}1 1.2 Sl 33.6',
        'a 1.2 Ou: teste', 'Outro título', '${m}3 Terceiro de teste.'],
      ['Gênesis 2', 'Título do dois', '${m}1 Primeiro do dois.',
        '${m}2 Segundo do dois.', 'Gênesis 3', '${m}3 Terceiro do dois.'],
    ];
    final r = parseBibleText(pages);
    String t(int c, int v) => r.verses.firstWhere((x) => x.book == 1 && x.chapter == c && x.verse == v).text;
    expect(r.verses.where((v) => v.book == 1 && v.chapter == 1).length, 3);
    expect(r.verses.where((v) => v.book == 1 && v.chapter == 2).length, 3);
    expect(t(1, 1), 'No princípio texto de teste um.');
    expect(t(1, 2), 'Segundo de teste, continua aqui.');
    expect(t(1, 3), 'Terceiro de teste.');
    expect(t(2, 3), 'Terceiro do dois.');
    expect(r.chapterPages[1002], 2);
  });
}
