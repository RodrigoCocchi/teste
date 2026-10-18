import 'dart:io';

import 'package:biblia_hinos_ccb/data/hymn_repository.dart';
import 'package:biblia_hinos_ccb/data/reading_plan.dart';
import 'package:biblia_hinos_ccb/services/app_services.dart';
import 'package:biblia_hinos_ccb/services/bible_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Texto de TESTE (fixture), não é texto bíblico.
BibleParseResult fixture() => BibleParseResult([
      ParsedVerse(1, 6, 13, 'Fixture: Noé recebeu ordem de fazer a arca.', 5),
      ParsedVerse(1, 6, 14, 'Fixture: segundo versículo.', 5),
      ParsedVerse(43, 11, 35, 'Fixture: Jesus chorou diante do túmulo.', 900),
      ParsedVerse(43, 11, 36, 'Fixture: o perdão e a misericórdia.', 900),
      ParsedVerse(44, 1, 23, 'Fixture: texto sem o nome esperado.', 950),
      ParsedVerse(44, 1, 24, 'Fixture: mais texto.', 950),
      ParsedVerse(44, 1, 25, 'Fixture: ainda mais.', 950),
      ParsedVerse(44, 1, 26, 'Fixture: fim.', 950),
    ], {1006: 5, 43011: 900}, {1: 1});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late App app;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('bh_test');
    app = await App.init(
      dbPath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
      dataDir: dir.path,
    );
  });

  tearDown(() => app.db.db.close());

  test('semeia perguntas, hinos, temas, estudos e plano', () async {
    final db = app.db.db;
    Future<int> count(String t) async =>
        (await db.rawQuery('SELECT COUNT(*) AS n FROM $t')).first['n'] as int;
    expect(await count('bible_book'), 66);
    expect(await count('bible_question'), 120);
    expect(await count('hymn'), 486);
    expect(await count('bible_theme'), 21);
    expect(await count('daily_study'), app.studies.length);
    expect(await count('reading_plan'), 1189);
    expect(app.hasBibleText, isFalse);
    expect(['fts5', 'fts4', 'none'], contains(app.db.ftsEngine));
  });

  test('grava texto, busca sem acento/caixa e expressão exata', () async {
    await app.storeBible(fixture(), 'teste');
    expect(app.verseCount, 8);
    final hits = await app.bible.search('PERDAO');
    expect(hits.total, 1);
    expect(hits.verses.single.chapter, 11);
    final exact = await app.bible.search('jesus chorou', exact: true);
    expect(exact.total, 1);
    final none = await app.bible.search('chorou jesus', exact: true);
    expect(none.total, app.db.ftsEngine == 'none' ? 1 : 0);
    final ch = await app.bible.chapter(43, 11);
    expect(ch.map((v) => v.verse), [35, 36]);
    final info = await app.bible.chapterInfo(43, 11);
    expect(info?.pdfPage, 900);
    // reimportação substitui tudo
    await app.storeBible(fixture(), 'teste 2');
    expect(app.verseCount, 8);
    expect((await app.bible.search('perdao')).total, 1);
  });

  test('confere respostas do quiz com o texto importado', () async {
    await app.storeBible(fixture(), 'teste');
    final byId = {for (final q in app.questions) q.id: q};
    expect(byId['F01']!.verifyStatus, 'conferida'); // Gn 6:13-22 contém "Noé" e "arca"
    expect(byId['M01']!.verifyStatus, 'divergente'); // At 1:23-26 sem "Matias" no fixture
    expect(byId['F02']!.verifyStatus, 'pendente'); // Gn 7:12 ausente
  });

  test('favoritos, marcações, histórico e progresso persistem', () async {
    final u = app.user;
    expect(await u.toggleFavorite('hymn', '120', 'Hino 120'), isTrue);
    expect(await u.isFavorite('hymn', '120'), isTrue);
    expect(await u.toggleFavorite('hymn', '120', 'Hino 120'), isFalse);
    await u.setBookmark(43011035, color: 2, note: 'nota');
    final marks = await u.bookmarksInChapter(43, 11);
    expect(marks[43011035]?.note, 'nota');
    await u.setBookmark(43011035);
    expect(await u.bookmarksInChapter(43, 11), isEmpty);
    await u.addHistory('chapter', '43:3', 'João 3');
    await u.addHistory('chapter', '43:3', 'João 3');
    expect((await u.history('chapter')).length, 1);

    await app.plan.setDone(const PlanChapter(1, 1), true);
    await app.plan.setDone(const PlanChapter(1, 2), true);
    await app.plan.setDone(const PlanChapter(1, 3), true);
    final p = app.plan.progressFrom(await app.plan.done());
    expect(p.doneChapters, 3);
    expect(p.daysDone, 1);
    expect(p.nextDay, 2);
  });

  test('mapeamento de páginas dos hinos', () async {
    const linear = LinearMapping(5, 2, 970);
    expect(HymnRepository.resolvePage(1, {}, linear), 5);
    expect(HymnRepository.resolvePage(3, {}, linear), 9);
    expect(HymnRepository.resolvePage(481, {}, linear), 970);
    expect(HymnRepository.resolvePage(10, {}, null), isNull);
    await app.hymns.setPage(10, 'do', 77);
    final pages = await app.hymns.manualPages('do');
    expect(HymnRepository.resolvePage(10, pages, linear), 77);
    expect((await app.hymns.search('120')).single.number, 120);
    expect((await app.hymns.search('coro 2')).single.number, 482);
    await app.hymns.setTitle(5, 'Título de teste');
    expect((await app.hymns.search('titulo teste')).single.number, 5);
  });

  test('importa JSON estruturado', () {
    final r = App.parseBibleJson('{"verses":[{"b":1,"c":1,"v":2,"t":"b"},{"b":1,"c":1,"v":1,"t":"a"},'
        '{"b":99,"c":1,"v":1,"t":"inválido"}]}');
    expect(r.verses.map((v) => v.verse), [1, 2]);
  });
}
