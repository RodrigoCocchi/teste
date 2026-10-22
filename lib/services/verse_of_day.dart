import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../core/bible_ref.dart';
import '../data/bible_repository.dart';
import '../data/content.dart';

/// Referências usadas no versículo do dia: as do índice temático (só trechos
/// com versículo indicado, até 3 versículos).
List<BibleRef> versePool(List<BibleThemeData> themes) {
  final seen = <String>{};
  return [
    for (final t in themes)
      for (final r in t.refs)
        if (r.verseStart != null && r.lastVerse - r.verseStart! <= 2 && seen.add(r.label)) r,
  ];
}

/// Referência do dia (a mesma para todos, muda à meia-noite, percorre a lista toda).
BibleRef refForDay(List<BibleRef> pool, DateTime day) {
  final days = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 86400000;
  // 7919 é primo: com listas que não sejam múltiplas dele, todos os itens aparecem.
  return pool[(days * 7919) % pool.length];
}

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Texto e referência do versículo do dia, ou null se a Bíblia ainda não foi indexada.
Future<(String, String)?> verseForDay(BibleRepository bible, List<BibleRef> pool, DateTime day) async {
  if (pool.isEmpty) return null;
  final r = refForDay(pool, day);
  final verses = await bible.chapter(r.bookId, r.chapter);
  final sel = verses.where((v) => v.verse >= r.verseStart! && v.verse <= r.lastVerse).toList();
  if (sel.isEmpty) return null;
  final text = sel.length == 1 ? sel.first.text : sel.map((v) => '${v.verse} ${v.text}').join(' ');
  return (text, '${r.label} (ARC)');
}

/// Grava os versículos dos próximos [days] dias para o widget da tela inicial.
Future<void> publishVerseWidget(BibleRepository bible, List<BibleThemeData> themes, {int days = 21}) async {
  final pool = versePool(themes);
  final now = DateTime.now();
  final map = <String, Map<String, String>>{};
  for (var i = 0; i < days; i++) {
    final d = now.add(Duration(days: i));
    final v = await verseForDay(bible, pool, d);
    if (v != null) map[dateKey(d)] = {'t': v.$1, 'r': v.$2};
  }
  if (map.isEmpty) return;
  await HomeWidget.saveWidgetData<String>('verses', jsonEncode(map));
  await HomeWidget.updateWidget(qualifiedAndroidName: 'br.pessoal.biblia_hinos_ccb.VerseWidgetProvider');
}
