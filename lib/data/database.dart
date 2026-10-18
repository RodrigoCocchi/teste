import 'package:sqflite/sqflite.dart';

import 'bible_books.dart';

/// Banco SQLite do aplicativo. O texto bíblico existe apenas em
/// `bible_verse`; o índice de busca (`verse_fts`) é "contentless" e guarda só
/// os termos normalizados, sem duplicar o texto.
class AppDatabase {
  AppDatabase._(this.db, this.ftsEngine);

  final Database db;

  /// 'fts5', 'fts4' ou 'none' (busca por LIKE).
  final String ftsEngine;

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance!;

  static const int schemaVersion = 1;

  static Future<AppDatabase> open(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _create(db),
      ),
    );
    final fts = await _ensureFts(db);
    _instance = AppDatabase._(db, fts);
    return _instance!;
  }

  static Future<void> _create(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE bible_book(
        id INTEGER PRIMARY KEY, name TEXT NOT NULL, abbrev TEXT NOT NULL,
        testament TEXT NOT NULL, chapters INTEGER NOT NULL, pdf_page INTEGER)''');
    batch.execute('''
      CREATE TABLE bible_chapter(
        id INTEGER PRIMARY KEY, book_id INTEGER NOT NULL REFERENCES bible_book(id),
        chapter INTEGER NOT NULL, verse_count INTEGER NOT NULL DEFAULT 0,
        pdf_page INTEGER, status TEXT NOT NULL DEFAULT 'ok',
        UNIQUE(book_id, chapter))''');
    batch.execute('''
      CREATE TABLE bible_verse(
        id INTEGER PRIMARY KEY, book_id INTEGER NOT NULL, chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL, text TEXT NOT NULL)''');
    batch.execute('CREATE INDEX idx_verse_chapter ON bible_verse(book_id, chapter, verse)');
    batch.execute('''
      CREATE TABLE bible_theme(
        id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, description TEXT)''');
    batch.execute('''
      CREATE TABLE theme_reference(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        theme_id INTEGER NOT NULL REFERENCES bible_theme(id) ON DELETE CASCADE,
        book_id INTEGER NOT NULL, chapter INTEGER NOT NULL,
        verse_start INTEGER NOT NULL, verse_end INTEGER, position INTEGER NOT NULL)''');
    batch.execute('CREATE INDEX idx_theme_ref ON theme_reference(theme_id, position)');
    batch.execute('''
      CREATE TABLE hymn(
        number INTEGER PRIMARY KEY, label TEXT NOT NULL, title TEXT,
        is_choir INTEGER NOT NULL DEFAULT 0, audio_path TEXT)''');
    batch.execute('''
      CREATE TABLE hymn_page(
        hymn_number INTEGER NOT NULL REFERENCES hymn(number),
        doc TEXT NOT NULL, page INTEGER NOT NULL, manual INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY(hymn_number, doc))''');
    batch.execute('CREATE INDEX idx_hymn_page ON hymn_page(doc, page)');
    batch.execute('''
      CREATE TABLE favorite(
        id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, ref_key TEXT NOT NULL,
        label TEXT NOT NULL, created_at INTEGER NOT NULL, UNIQUE(kind, ref_key))''');
    batch.execute('''
      CREATE TABLE bookmark(
        verse_id INTEGER PRIMARY KEY, color INTEGER, note TEXT,
        updated_at INTEGER NOT NULL)''');
    batch.execute('''
      CREATE TABLE reading_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, ref_key TEXT NOT NULL,
        label TEXT NOT NULL, at INTEGER NOT NULL)''');
    batch.execute('CREATE INDEX idx_history ON reading_history(kind, at DESC)');
    batch.execute('''
      CREATE TABLE bible_question(
        id TEXT PRIMARY KEY, difficulty TEXT NOT NULL, category TEXT NOT NULL,
        question TEXT NOT NULL, options TEXT NOT NULL, answer INTEGER NOT NULL,
        explanation TEXT NOT NULL, refs TEXT NOT NULL, keywords TEXT NOT NULL,
        verify_status TEXT NOT NULL DEFAULT 'pendente')''');
    batch.execute('CREATE INDEX idx_question_diff ON bible_question(difficulty)');
    batch.execute('''
      CREATE TABLE quiz_session(
        id INTEGER PRIMARY KEY AUTOINCREMENT, difficulty TEXT NOT NULL,
        total INTEGER NOT NULL, correct INTEGER NOT NULL DEFAULT 0,
        started_at INTEGER NOT NULL, finished_at INTEGER)''');
    batch.execute('''
      CREATE TABLE quiz_answer(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES quiz_session(id) ON DELETE CASCADE,
        question_id TEXT NOT NULL, chosen INTEGER NOT NULL, correct INTEGER NOT NULL,
        at INTEGER NOT NULL)''');
    batch.execute('CREATE INDEX idx_answer_q ON quiz_answer(question_id, at DESC)');
    batch.execute('''
      CREATE TABLE daily_study(
        id INTEGER PRIMARY KEY, day INTEGER NOT NULL, title TEXT NOT NULL,
        theme TEXT NOT NULL, refs TEXT NOT NULL, context TEXT NOT NULL,
        reflection TEXT NOT NULL, questions TEXT NOT NULL)''');
    batch.execute('''
      CREATE TABLE reading_plan(
        day INTEGER NOT NULL, position INTEGER NOT NULL, book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL, PRIMARY KEY(day, position))''');
    batch.execute('''
      CREATE TABLE reading_progress(
        book_id INTEGER NOT NULL, chapter INTEGER NOT NULL, done_at INTEGER NOT NULL,
        PRIMARY KEY(book_id, chapter))''');
    for (final b in bibleBooks) {
      batch.insert('bible_book', {
        'id': b.id,
        'name': b.name,
        'abbrev': b.abbrev,
        'testament': b.isOldTestament ? 'AT' : 'NT',
        'chapters': b.chapters,
      });
    }
    await batch.commit(noResult: true);
  }

  static Future<String> _ensureFts(Database db) async {
    final existing = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE name = 'verse_fts'");
    if (existing.isNotEmpty) {
      final sql = (existing.first['sql'] as String? ?? '').toLowerCase();
      return sql.contains('fts5') ? 'fts5' : 'fts4';
    }
    try {
      await db.execute(
          "CREATE VIRTUAL TABLE verse_fts USING fts5(body, content='', tokenize='unicode61')");
      return 'fts5';
    } on Object {
      try {
        await db.execute("CREATE VIRTUAL TABLE verse_fts USING fts4(content='', body)");
        return 'fts4';
      } on Object {
        return 'none';
      }
    }
  }
}
