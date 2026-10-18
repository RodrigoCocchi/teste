import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/quiz_repository.dart';
import '../services/app_services.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'nav.dart';
import 'quiz_play_screen.dart';

/// Configuração da partida, histórico e estatísticas do quiz.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String _difficulty = 'facil';
  int _count = 10;
  List<QuizSessionSummary> _sessions = [];
  QuizStats? _stats;
  Set<String> _wrong = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = App.I;
    final sessions = await app.quiz.sessions(limit: 20);
    final stats = await app.quiz.stats(app.questions);
    final wrong = await app.quiz.wrongQuestionIds();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _stats = stats;
        _wrong = wrong;
      });
    }
  }

  List<QuizQuestion> _pool() => _difficulty == 'todas'
      ? App.I.questions
      : App.I.questions.where((q) => q.difficulty == _difficulty).toList();

  Future<void> _start(List<QuizQuestion> pool, String difficulty, {int? count}) async {
    final list = [...pool]..shuffle();
    final n = count == null || count == 0 ? list.length : count.clamp(1, list.length);
    await push(context, QuizPlayScreen(questions: list.take(n).toList(), difficulty: difficulty));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = App.I;
    final verified = app.questions.where((q) => q.verifyStatus == 'conferida').length;
    final pool = _pool();
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Bíblico')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          const SectionTitle('Dificuldade'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'facil', label: Text('Fácil')),
                ButtonSegment(value: 'medio', label: Text('Média')),
                ButtonSegment(value: 'dificil', label: Text('Difícil')),
                ButtonSegment(value: 'todas', label: Text('Todas')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (s) => setState(() => _difficulty = s.first),
            ),
          ),
          const SectionTitle('Quantidade de perguntas'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, children: [
              for (final n in [10, 20, 30, 0])
                ChoiceChip(
                  label: Text(n == 0 ? 'Todas (${pool.length})' : '$n'),
                  selected: _count == n,
                  onSelected: (_) => setState(() => _count = n),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Começar'),
              onPressed: () => _start(pool, _difficulty, count: _count),
            ),
          ),
          if (_wrong.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.replay),
                label: Text('Refazer perguntas erradas (${_wrong.length})'),
                onPressed: () => _start(
                    app.questions.where((q) => _wrong.contains(q.id)).toList(), 'erradas'),
              ),
            ),
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                app.hasBibleText
                    ? '$verified de ${app.questions.length} perguntas conferidas com o texto bíblico importado.'
                    : 'As respostas ainda não foram conferidas com o texto bíblico: importe e indexe a '
                        'Bíblia para que cada pergunta seja verificada pelas referências.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (_stats != null && _stats!.answered > 0) ...[
            const SectionTitle('Estatísticas'),
            ListTile(
              leading: const Icon(Icons.insights, color: AppColors.gold),
              title: Text('${(_stats!.rate * 100).round()}% de acertos'),
              subtitle: Text('${_stats!.correct} de ${_stats!.answered} respostas · ${_stats!.sessions} partidas'),
            ),
            for (final d in QuizQuestion.difficulties)
              if (_stats!.byDifficulty[d] != null)
                ListTile(
                  dense: true,
                  title: Text(QuizQuestion.difficultyLabel(d)),
                  trailing: Text('${_stats!.byDifficulty[d]!.$2}/${_stats!.byDifficulty[d]!.$1}'),
                ),
          ],
          if (_sessions.isNotEmpty) ...[
            const SectionTitle('Histórico de partidas'),
            for (final s in _sessions)
              ListTile(
                dense: true,
                leading: const Icon(Icons.flag_outlined),
                title: Text('${QuizQuestion.difficultyLabel(s.difficulty)} · ${s.correct}/${s.total}'),
                subtitle: Text(
                    '${s.startedAt.day.toString().padLeft(2, '0')}/${s.startedAt.month.toString().padLeft(2, '0')}/${s.startedAt.year} '
                    '${s.startedAt.hour.toString().padLeft(2, '0')}:${s.startedAt.minute.toString().padLeft(2, '0')}'),
              ),
            TextButton(
              onPressed: () async {
                await App.I.quiz.clearHistory();
                _load();
              },
              child: const Text('Apagar histórico do quiz'),
            ),
          ],
        ]),
      ),
    );
  }
}
