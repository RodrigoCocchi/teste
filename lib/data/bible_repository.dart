import 'package:sqflite/sqflite.dart';

import '../core/bible_ref.dart';
import '../core/text_utils.dart';
import '../services/bible_parser.dart';
import 'database.dart';

class Verse {
  const Verse(this.id, this.bookId, this.chapter, this.verse, this.text);
  final int id;
  final int bookId;
  final int chapter;
  final int verse;
  final String text;

  static int makeId(int book, int chapter, int verse) =>
      book * 1000000 + chapter * 1000 + verse;

  BibleRef get ref => BibleRef(bookId, chapter, verse);

  factory Verse.fromRow(Map<String, Object?> r) => Verse(
        r['id'] as int,
        r['book_id'] as int,
        r['chapter'] as int,
        r['verse'] as int,
        r['text'] as String,
      );
}

class ChapterInfo {
  const ChapterInfo(this.verseCount, this.pdfPage, this.status);
  final int verseCount;
  final int? pdfPage;
  final String status;
  bool get isSuspect => status != 'ok';
}

class SearchHits {
  const SearchHits(this.verses, this.total);
  final List<Verse> verses;
  final int total;
}

class BibleRepository {
  BibleRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  Future<int> verseCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM bible_verse')) ?? 0;

  Future<int> chapterCount() async => Sqflite.firstIntValue(await _db
          .rawQuery('SELECT COUNT(*) FROM bible_chapter WHERE verse_count > 0')) ??
      0;

  /// Substitui todo o texto estruturado (nova importação).
  Future<void> replaceAll(BibleParseResult r,
      {void Function(double progress)? onProgress}) async {
    await _db.transaction((txn) async {
      await txn.delete('bible_verse');
      await txn.delete('bible_chapter');
      await txn.execute('DROP TABLE IF EXISTS verse_fts');
      if (_app.ftsEngine == 'fts5') {
        await txn.execute(
            "CREATE VIRTUAL TABLE verse_fts USING fts5(body, content='', tokenize='unicode61')");
      } else if (_app.ftsEngine == 'fts4') {
        await txn.execute("CREATE VIRTUAL TABLE verse_fts USING fts4(content='', body)");
      }
      final counts = <int, int>{};
      for (final v in r.verses) {
        final key = v.book * 1000 + v.chapter;
        if (v.verse > (counts[key] ?? 0)) counts[key] = v.verse;
      }
      for (final e in counts.entries) {
        await txn.insert('bible_chapter', {
          'id': e.key,
          'book_id': e.key ~/ 1000,
          'chapter': e.key % 1000,
          'verse_count': e.value,
          'pdf_page': r.chapterPages[e.key],
          'status': r.suspectChapters.contains(e.key) ? 'conferir' : 'ok',
        });
      }
      const chunk = 1000;
      for (var i = 0; i < r.verses.length; i += chunk) {
        final batch = txn.batch();
        final end = i + chunk > r.verses.length ? r.verses.length : i + chunk;
        for (final v in r.verses.sublist(i, end)) {
          final id = Verse.makeId(v.book, v.chapter, v.verse);
          batch.insert('bible_verse', {
            'id': id,
            'book_id': v.book,
            'chapter': v.chapter,
            'verse': v.verse,
            'text': v.text,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          if (_app.ftsEngine != 'none') {
            batch.rawInsert('INSERT INTO verse_fts(rowid, body) VALUES(?, ?)',
                [id, ftsText(v.text)]);
          }
        }
        await batch.commit(noResult: true);
        onProgress?.call(end / r.verses.length);
      }
      for (final e in r.bookPages.entries) {
        await txn.update('bible_book', {'pdf_page': e.value},
            where: 'id = ?', whereArgs: [e.key]);
      }
    });
  }

  Future<List<Verse>> chapter(int book, int chapter) async {
    final rows = await _db.query('bible_verse',
        where: 'book_id = ? AND chapter = ?',
        whereArgs: [book, chapter],
        orderBy: 'verse');
    return rows.map(Verse.fromRow).toList();
  }

  Future<List<Verse>> range(BibleRef ref) async {
    final start = ref.verseStart ?? 1;
    final end = ref.verseEnd ?? ref.verseStart ?? 999;
    final rows = await _db.query('bible_verse',
        where: 'id BETWEEN ? AND ?',
        whereArgs: [
          Verse.makeId(ref.bookId, ref.chapter, start),
          Verse.makeId(ref.bookId, ref.chapter, end),
        ],
        orderBy: 'id');
    return rows.map(Verse.fromRow).toList();
  }

  Future<Verse?> verseById(int id) async {
    final rows = await _db.query('bible_verse', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Verse.fromRow(rows.first);
  }

  Future<ChapterInfo?> chapterInfo(int book, int chapter) async {
    final rows = await _db.query('bible_chapter',
        where: 'id = ?', whereArgs: [book * 1000 + chapter]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ChapterInfo(r['verse_count'] as int, r['pdf_page'] as int?, r['status'] as String);
  }

  /// Capítulos com texto estruturado em um livro.
  Future<Set<int>> availableChapters(int book) async {
    final rows = await _db.query('bible_chapter',
        columns: ['chapter'], where: 'book_id = ? AND verse_count > 0', whereArgs: [book]);
    return {for (final r in rows) r['chapter'] as int};
  }

  Future<Map<int, int>> chapterCountsByBook() async {
    final rows = await _db.rawQuery(
        'SELECT book_id, COUNT(*) AS n FROM bible_chapter WHERE verse_count > 0 GROUP BY book_id');
    return {for (final r in rows) r['book_id'] as int: r['n'] as int};
  }

  Future<int?> bookPdfPage(int book) async {
    final rows = await _db.query('bible_book',
        columns: ['pdf_page'], where: 'id = ?', whereArgs: [book]);
    return rows.isEmpty ? null : rows.first['pdf_page'] as int?;
  }

  Future<void> setBookPdfPage(int book, int page) =>
      _db.update('bible_book', {'pdf_page': page}, where: 'id = ?', whereArgs: [book]);

  /// Busca textual sem diferenciar maiúsculas/acentos. Com [exact], procura a
  /// expressão exata; senão, todas as palavras (com prefixo na última).
  Future<SearchHits> search(String query, {bool exact = false, int limit = 100}) async {
    final words = tokenize(query);
    if (words.isEmpty) return const SearchHits([], 0);
    if (_app.ftsEngine == 'none') {
      final where = words.map((_) => 'text LIKE ?').join(' AND ');
      final args = words.map((w) => '%$w%').toList();
      final rows = await _db.query('bible_verse',
          where: where, whereArgs: args, orderBy: 'id', limit: limit);
      final total = Sqflite.firstIntValue(await _db.rawQuery(
              'SELECT COUNT(*) FROM bible_verse WHERE $where', args)) ??
          0;
      return SearchHits(rows.map(Verse.fromRow).toList(), total);
    }
    final match = exact
        ? '"${words.join(' ')}"'
        : [for (var i = 0; i < words.length; i++) i == words.length - 1 && words[i].length >= 3 ? '${words[i]}*' : words[i]]
            .join(' ');
    final total = Sqflite.firstIntValue(await _db.rawQuery(
            'SELECT COUNT(*) FROM verse_fts WHERE verse_fts MATCH ?', [match])) ??
        0;
    final rows = await _db.rawQuery(
        'SELECT v.* FROM verse_fts f JOIN bible_verse v ON v.id = f.rowid '
        'WHERE verse_fts MATCH ? ORDER BY v.id LIMIT ?',
        [match, limit]);
    return SearchHits(rows.map(Verse.fromRow).toList(), total);
  }
}
