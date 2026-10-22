import 'package:sqflite/sqflite.dart';

import 'database.dart';

class PrayerItem {
  const PrayerItem(this.id, this.text, this.createdAt, this.answeredAt, this.note);
  final int id;
  final String text;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final String? note; // como foi atendido
  bool get answered => answeredAt != null;
}

/// Lista de oração pessoal (fica só no aparelho).
class PrayerRepository {
  PrayerRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  static Future<void> ensureTable(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS prayer(
        id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, created_at INTEGER NOT NULL,
        answered_at INTEGER, note TEXT)''');

  PrayerItem _row(Map<String, Object?> r) => PrayerItem(
        r['id'] as int,
        r['text'] as String,
        DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        r['answered_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['answered_at'] as int),
        r['note'] as String?,
      );

  Future<List<PrayerItem>> list({required bool answered}) async => [
        for (final r in await _db.query('prayer',
            where: answered ? 'answered_at IS NOT NULL' : 'answered_at IS NULL',
            orderBy: answered ? 'answered_at DESC' : 'created_at DESC'))
          _row(r),
      ];

  Future<int> add(String text) =>
      _db.insert('prayer', {'text': text.trim(), 'created_at': DateTime.now().millisecondsSinceEpoch});

  Future<void> edit(int id, String text) =>
      _db.update('prayer', {'text': text.trim()}, where: 'id = ?', whereArgs: [id]);

  Future<void> setAnswered(int id, bool answered, {String? note}) => _db.update(
      'prayer',
      {
        'answered_at': answered ? DateTime.now().millisecondsSinceEpoch : null,
        'note': answered && (note?.trim().isNotEmpty ?? false) ? note!.trim() : null,
      },
      where: 'id = ?',
      whereArgs: [id]);

  Future<void> remove(int id) => _db.delete('prayer', where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, Object?>>> rawRows() => _db.query('prayer');
}
