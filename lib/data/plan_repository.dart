import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'reading_plan.dart';

class PlanProgress {
  const PlanProgress(this.doneChapters, this.totalChapters, this.daysDone, this.nextDay);
  final int doneChapters;
  final int totalChapters;
  final int daysDone;
  final int nextDay; // primeiro dia (1-based) com capítulos pendentes
  double get fraction => totalChapters == 0 ? 0 : doneChapters / totalChapters;
}

/// Plano anual de leitura (tabela reading_plan) e progresso (reading_progress).
class PlanRepository {
  PlanRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  late final List<List<PlanChapter>> plan = buildReadingPlan();

  Future<void> seed() async {
    final n = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM reading_plan')) ?? 0;
    final total = plan.fold<int>(0, (s, d) => s + d.length);
    if (n == total) return;
    final batch = _db.batch()..delete('reading_plan');
    for (var d = 0; d < plan.length; d++) {
      for (var i = 0; i < plan[d].length; i++) {
        batch.insert('reading_plan', {
          'day': d + 1,
          'position': i,
          'book_id': plan[d][i].bookId,
          'chapter': plan[d][i].chapter,
        });
      }
    }
    await batch.commit(noResult: true);
  }

  Future<Map<PlanChapter, DateTime>> done() async {
    final rows = await _db.query('reading_progress');
    return {
      for (final r in rows)
        PlanChapter(r['book_id'] as int, r['chapter'] as int):
            DateTime.fromMillisecondsSinceEpoch(r['done_at'] as int),
    };
  }

  Future<void> setDone(PlanChapter c, bool value) async {
    if (value) {
      await _db.insert('reading_progress',
          {'book_id': c.bookId, 'chapter': c.chapter, 'done_at': DateTime.now().millisecondsSinceEpoch},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await _db.delete('reading_progress',
          where: 'book_id = ? AND chapter = ?', whereArgs: [c.bookId, c.chapter]);
    }
  }

  Future<void> reset() => _db.delete('reading_progress');

  PlanProgress progressFrom(Map<PlanChapter, DateTime> done) {
    var daysDone = 0;
    int? next;
    for (var d = 0; d < plan.length; d++) {
      final complete = plan[d].every(done.containsKey);
      if (complete) {
        daysDone++;
      } else {
        next ??= d + 1;
      }
    }
    final total = plan.fold<int>(0, (s, d) => s + d.length);
    return PlanProgress(done.length, total, daysDone, next ?? plan.length);
  }
}
