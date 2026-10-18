import 'package:sqflite/sqflite.dart';

import 'database.dart';

class Favorite {
  const Favorite(this.kind, this.refKey, this.label, this.createdAt);
  final String kind; // verse | hymn | study | theme
  final String refKey;
  final String label;
  final DateTime createdAt;
}

class Bookmark {
  const Bookmark(this.verseId, this.color, this.note);
  final int verseId;
  final int? color;
  final String? note;
}

class HistoryEntry {
  const HistoryEntry(this.kind, this.refKey, this.label, this.at);
  final String kind; // chapter | hymn
  final String refKey;
  final String label;
  final DateTime at;
}

/// Favoritos, marcações/anotações e histórico.
class UserRepository {
  UserRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  Future<bool> isFavorite(String kind, String key) async =>
      (await _db.query('favorite',
              where: 'kind = ? AND ref_key = ?', whereArgs: [kind, key], limit: 1))
          .isNotEmpty;

  /// Retorna o novo estado (true = favoritado).
  Future<bool> toggleFavorite(String kind, String key, String label) async {
    if (await isFavorite(kind, key)) {
      await _db.delete('favorite', where: 'kind = ? AND ref_key = ?', whereArgs: [kind, key]);
      return false;
    }
    await _db.insert('favorite', {
      'kind': kind,
      'ref_key': key,
      'label': label,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return true;
  }

  Future<Set<String>> favoriteKeys(String kind) async {
    final rows = await _db.query('favorite',
        columns: ['ref_key'], where: 'kind = ?', whereArgs: [kind]);
    return {for (final r in rows) r['ref_key'] as String};
  }

  Future<List<Favorite>> favorites({String? kind}) async {
    final rows = await _db.query('favorite',
        where: kind == null ? null : 'kind = ?',
        whereArgs: kind == null ? null : [kind],
        orderBy: 'created_at DESC');
    return [
      for (final r in rows)
        Favorite(r['kind'] as String, r['ref_key'] as String, r['label'] as String,
            DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int)),
    ];
  }

  Future<Map<int, Bookmark>> bookmarksInChapter(int book, int chapter) async {
    final base = book * 1000000 + chapter * 1000;
    final rows = await _db.query('bookmark',
        where: 'verse_id BETWEEN ? AND ?', whereArgs: [base, base + 999]);
    return {
      for (final r in rows)
        r['verse_id'] as int:
            Bookmark(r['verse_id'] as int, r['color'] as int?, r['note'] as String?),
    };
  }

  Future<List<Bookmark>> allBookmarks() async {
    final rows = await _db.query('bookmark', orderBy: 'verse_id');
    return [
      for (final r in rows)
        Bookmark(r['verse_id'] as int, r['color'] as int?, r['note'] as String?),
    ];
  }

  /// Define cor e/ou nota; remove o registro quando ambos ficam vazios.
  Future<void> setBookmark(int verseId, {int? color, String? note}) async {
    final empty = color == null && (note == null || note.trim().isEmpty);
    if (empty) {
      await _db.delete('bookmark', where: 'verse_id = ?', whereArgs: [verseId]);
      return;
    }
    await _db.insert(
      'bookmark',
      {
        'verse_id': verseId,
        'color': color,
        'note': note?.trim().isEmpty ?? true ? null : note!.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addHistory(String kind, String key, String label) async {
    await _db.delete('reading_history',
        where: 'kind = ? AND ref_key = ?', whereArgs: [kind, key]);
    await _db.insert('reading_history', {
      'kind': kind,
      'ref_key': key,
      'label': label,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<HistoryEntry>> history(String kind, {int limit = 50}) async {
    final rows = await _db.query('reading_history',
        where: 'kind = ?', whereArgs: [kind], orderBy: 'at DESC', limit: limit);
    return [
      for (final r in rows)
        HistoryEntry(r['kind'] as String, r['ref_key'] as String, r['label'] as String,
            DateTime.fromMillisecondsSinceEpoch(r['at'] as int)),
    ];
  }

  Future<void> clearHistory(String kind) =>
      _db.delete('reading_history', where: 'kind = ?', whereArgs: [kind]);
}
