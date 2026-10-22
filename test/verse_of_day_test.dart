import 'package:biblia_hinos_ccb/core/bible_ref.dart';
import 'package:biblia_hinos_ccb/data/content.dart';
import 'package:biblia_hinos_ccb/services/verse_of_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final themes = [
    BibleThemeData(1, 'Amor', '', const [
      BibleRef(43, 3, 16),
      BibleRef(46, 13), // capítulo inteiro: fica de fora
      BibleRef(62, 4, 7, 8),
      BibleRef(19, 119, 1, 20), // longo demais: fica de fora
    ]),
    BibleThemeData(2, 'Fé', '', const [BibleRef(43, 3, 16), BibleRef(58, 11, 1)]),
  ];

  test('lista sem repetição, só trechos curtos com versículo', () {
    expect(versePool(themes).map((r) => r.label), ['João 3:16', '1 João 4:7-8', 'Hebreus 11:1']);
  });

  test('mesmo dia, mesmo versículo; dias seguidos mudam', () {
    final pool = versePool(themes);
    final d = DateTime(2026, 10, 22, 8);
    expect(refForDay(pool, d).label, refForDay(pool, DateTime(2026, 10, 22, 23)).label);
    final week = {for (var i = 0; i < 3; i++) refForDay(pool, d.add(Duration(days: i))).label};
    expect(week.length, 3);
    expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
