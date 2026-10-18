import 'package:sqflite/sqflite.dart';

import '../core/text_utils.dart';
import 'database.dart';

/// Hinário 5: 480 hinos + 6 coros (armazenados como 481–486).
class Hymn {
  const Hymn(this.number, this.title, this.audioPath);
  final int number;
  final String? title;
  final String? audioPath;

  bool get isChoir => number > Hymns.hymnCount;
  String get label => labelFor(number);
  String get display => title == null || title!.isEmpty ? label : '$label — $title';

  static String labelFor(int n) =>
      n > Hymns.hymnCount ? 'Coro ${n - Hymns.hymnCount}' : 'Hino $n';
}

class Hymns {
  static const hymnCount = 480;
  static const choirCount = 6;
  static const total = hymnCount + choirCount;
  static const docs = ['do', 'orgao'];
  static String docLabel(String doc) => doc == 'do' ? 'Hinário em Dó' : 'Hinário para órgão';
}

/// Mapeamento linear: hino 1 na página [firstPage], [pagesPerHymn] por hino;
/// coros a partir de [choirFirstPage] (opcional).
class LinearMapping {
  const LinearMapping(this.firstPage, this.pagesPerHymn, this.choirFirstPage);
  final int firstPage;
  final int pagesPerHymn;
  final int? choirFirstPage;
}

class HymnRepository {
  HymnRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  Future<void> seed() async {
    final n = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM hymn')) ?? 0;
    if (n == Hymns.total) return;
    final batch = _db.batch();
    for (var i = 1; i <= Hymns.total; i++) {
      batch.insert(
        'hymn',
        {'number': i, 'label': Hymn.labelFor(i), 'is_choir': i > Hymns.hymnCount ? 1 : 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Hymn>> all() async {
    final rows = await _db.query('hymn', orderBy: 'number');
    return [
      for (final r in rows)
        Hymn(r['number'] as int, r['title'] as String?, r['audio_path'] as String?),
    ];
  }

  Future<Hymn> get(int number) async {
    final r = (await _db.query('hymn', where: 'number = ?', whereArgs: [number])).first;
    return Hymn(number, r['title'] as String?, r['audio_path'] as String?);
  }

  Future<void> setTitle(int number, String? title) => _db.update(
      'hymn', {'title': title?.trim().isEmpty ?? true ? null : title!.trim()},
      where: 'number = ?', whereArgs: [number]);

  Future<void> setAudio(int number, String? path) =>
      _db.update('hymn', {'audio_path': path}, where: 'number = ?', whereArgs: [number]);

  /// Busca por número ("120", "hino 120", "coro 3") ou título.
  Future<List<Hymn>> search(String query) async {
    final q = normalize(query.trim());
    if (q.isEmpty) return all();
    final num = RegExp(r'^(?:hino\s*)?(\d{1,3})$').firstMatch(q);
    final choir = RegExp(r'^coro\s*(\d)$').firstMatch(q);
    final list = await all();
    if (num != null) {
      final n = int.parse(num[1]!);
      return list.where((h) => h.number == n && !h.isChoir).toList();
    }
    if (choir != null) {
      final n = Hymns.hymnCount + int.parse(choir[1]!);
      return list.where((h) => h.number == n).toList();
    }
    final words = tokenize(q.replaceFirst(RegExp(r'^hino\s+'), ''));
    return list.where((h) {
      final t = tokenize(h.title ?? '');
      return words.every((w) => t.any((x) => x.startsWith(w)));
    }).toList();
  }

  Future<Map<int, int>> manualPages(String doc) async {
    final rows = await _db.query('hymn_page', where: 'doc = ?', whereArgs: [doc]);
    return {for (final r in rows) r['hymn_number'] as int: r['page'] as int};
  }

  Future<void> setPage(int number, String doc, int page, {bool manual = true}) =>
      _db.insert('hymn_page', {'hymn_number': number, 'doc': doc, 'page': page, 'manual': manual ? 1 : 0},
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> clearPage(int number, String doc) =>
      _db.delete('hymn_page', where: 'hymn_number = ? AND doc = ?', whereArgs: [number, doc]);

  Future<void> clearAutoPages(String doc) =>
      _db.delete('hymn_page', where: 'doc = ? AND manual = 0', whereArgs: [doc]);

  /// Página do hino: mapeamento individual (manual/detectado) ou linear.
  static int? resolvePage(int number, Map<int, int> pages, LinearMapping? linear) {
    final p = pages[number];
    if (p != null) return p;
    if (linear == null) return null;
    if (number > Hymns.hymnCount) {
      final first = linear.choirFirstPage;
      if (first == null) return null;
      return first + (number - Hymns.hymnCount - 1) * linear.pagesPerHymn;
    }
    return linear.firstPage + (number - 1) * linear.pagesPerHymn;
  }
}
