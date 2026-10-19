import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/text_utils.dart';
import 'bible_repository.dart';
import 'content.dart';
import 'database.dart';

class QuizSessionSummary {
  const QuizSessionSummary(this.id, this.difficulty, this.total, this.correct, this.startedAt);
  final int id;
  final String difficulty;
  final int total;
  final int correct;
  final DateTime startedAt;
}

class QuizStats {
  const QuizStats(this.sessions, this.answered, this.correct, this.byDifficulty);
  final int sessions;
  final int answered;
  final int correct;

  /// dificuldade → (respondidas, acertos)
  final Map<String, (int, int)> byDifficulty;
  double get rate => answered == 0 ? 0 : correct / answered;
}

/// Perguntas, partidas, respostas e conferência das respostas com o texto.
class QuizRepository {
  QuizRepository(this._app);
  final AppDatabase _app;
  Database get _db => _app.db;

  /// Sincroniza a tabela bible_question com o JSON (mantém o status).
  Future<void> seed(List<QuizQuestion> questions) async {
    final rows = await _db.query('bible_question', columns: ['id', 'verify_status']);
    final status = {for (final r in rows) r['id'] as String: r['verify_status'] as String};
    final batch = _db.batch();
    batch.delete('bible_question');
    for (final q in questions) {
      q.verifyStatus = status[q.id] ?? 'pendente';
      batch.insert('bible_question', {
        'id': q.id,
        'difficulty': q.difficulty,
        'category': q.category,
        'question': q.question,
        'options': jsonEncode(q.options),
        'answer': q.answer,
        'explanation': q.explanation,
        'refs': jsonEncode(q.refs.map((r) => r.code).toList()),
        'keywords': jsonEncode(q.keywords),
        'verify_status': q.verifyStatus,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Carrega o status de conferência gravado (sem regravar as perguntas).
  Future<void> loadStatus(List<QuizQuestion> questions) async {
    final rows = await _db.query('bible_question', columns: ['id', 'verify_status']);
    final status = {for (final r in rows) r['id'] as String: r['verify_status'] as String};
    for (final q in questions) {
      q.verifyStatus = status[q.id] ?? 'pendente';
    }
  }

  /// Confere cada pergunta com o texto bíblico importado: todas as palavras-
  /// -chave devem aparecer no texto das referências citadas.
  Future<Map<String, int>> verifyAgainstBible(
      List<QuizQuestion> questions, BibleRepository bible) async {
    final counts = <String, int>{'conferida': 0, 'divergente': 0, 'pendente': 0};
    final batch = _db.batch();
    for (final q in questions) {
      final words = <String>{};
      var missingText = false;
      for (final ref in q.refs) {
        final verses = await bible.range(ref);
        if (verses.isEmpty) missingText = true;
        for (final v in verses) {
          words.addAll(tokenize(v.text));
        }
      }
      final ok = q.keywords.every((k) => tokenize(k).every(words.contains));
      q.verifyStatus = missingText ? 'pendente' : (ok ? 'conferida' : 'divergente');
      counts[q.verifyStatus] = counts[q.verifyStatus]! + 1;
      batch.update('bible_question', {'verify_status': q.verifyStatus},
          where: 'id = ?', whereArgs: [q.id]);
    }
    await batch.commit(noResult: true);
    return counts;
  }

  Future<int> startSession(String difficulty, int total) => _db.insert('quiz_session', {
        'difficulty': difficulty,
        'total': total,
        'started_at': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> recordAnswer(int sessionId, String questionId, int chosen, bool correct) async {
    await _db.insert('quiz_answer', {
      'session_id': sessionId,
      'question_id': questionId,
      'chosen': chosen,
      'correct': correct ? 1 : 0,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    await _db.rawUpdate(
        'UPDATE quiz_session SET correct = (SELECT COUNT(*) FROM quiz_answer '
        'WHERE session_id = ? AND correct = 1) WHERE id = ?',
        [sessionId, sessionId]);
  }

  Future<void> finishSession(int sessionId) => _db.update(
      'quiz_session', {'finished_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [sessionId]);

  Future<List<QuizSessionSummary>> sessions({int limit = 50}) async {
    final rows = await _db.query('quiz_session', orderBy: 'started_at DESC', limit: limit);
    return [
      for (final r in rows)
        QuizSessionSummary(r['id'] as int, r['difficulty'] as String, r['total'] as int,
            r['correct'] as int, DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int)),
    ];
  }

  /// Perguntas cuja resposta mais recente foi errada.
  Future<Set<String>> wrongQuestionIds() async {
    final rows = await _db.rawQuery(
        'SELECT question_id, correct FROM quiz_answer a WHERE at = '
        '(SELECT MAX(at) FROM quiz_answer b WHERE b.question_id = a.question_id)');
    return {
      for (final r in rows)
        if (r['correct'] == 0) r['question_id'] as String,
    };
  }

  Future<QuizStats> stats(List<QuizQuestion> questions) async {
    final diff = {for (final q in questions) q.id: q.difficulty};
    final rows = await _db.query('quiz_answer', columns: ['question_id', 'correct']);
    final by = <String, (int, int)>{};
    var correct = 0;
    for (final r in rows) {
      final d = diff[r['question_id']] ?? '?';
      final ok = r['correct'] == 1;
      if (ok) correct++;
      final cur = by[d] ?? (0, 0);
      by[d] = (cur.$1 + 1, cur.$2 + (ok ? 1 : 0));
    }
    final sessions =
        Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM quiz_session')) ?? 0;
    return QuizStats(sessions, rows.length, correct, by);
  }

  Future<void> clearHistory() async {
    await _db.delete('quiz_answer');
    await _db.delete('quiz_session');
  }
}
