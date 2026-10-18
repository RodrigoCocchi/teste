import 'dart:math';

import 'package:flutter/material.dart';

import '../data/content.dart';
import '../services/app_services.dart';
import '../theme.dart';
import 'nav.dart';

/// Uma pergunta por tela, com feedback, explicação e referência.
class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({super.key, required this.questions, required this.difficulty});
  final List<QuizQuestion> questions;
  final String difficulty;
  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _index = 0;
  int? _chosen; // índice original da alternativa escolhida
  int _correct = 0;
  int? _session;
  final _wrong = <QuizQuestion>[];
  late List<List<int>> _orders;
  bool _finished = false;

  QuizQuestion get _q => widget.questions[_index];

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    // Embaralha as alternativas para que a posição da correta varie.
    _orders = [for (final _ in widget.questions) ([0, 1, 2, 3]..shuffle(rnd))];
    App.I.quiz.startSession(widget.difficulty, widget.questions.length).then((id) => _session = id);
  }

  Future<void> _answer(int original) async {
    if (_chosen != null) return;
    final ok = original == _q.answer;
    setState(() {
      _chosen = original;
      if (ok) {
        _correct++;
      } else {
        _wrong.add(_q);
      }
    });
    final s = _session;
    if (s != null) await App.I.quiz.recordAnswer(s, _q.id, original, ok);
  }

  Future<void> _next() async {
    if (_index + 1 >= widget.questions.length) {
      final s = _session;
      if (s != null) await App.I.quiz.finishSession(s);
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _chosen = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _result(context);
    final t = Theme.of(context);
    final q = _q;
    final answered = _chosen != null;
    return Scaffold(
      appBar: AppBar(title: Text('Pergunta ${_index + 1} de ${widget.questions.length}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        LinearProgressIndicator(value: (_index + (answered ? 1 : 0)) / widget.questions.length),
        const SizedBox(height: 12),
        Row(children: [
          Chip(label: Text(QuizQuestion.difficultyLabel(q.difficulty))),
          const SizedBox(width: 6),
          Expanded(child: Text(q.category, style: t.textTheme.labelMedium, overflow: TextOverflow.ellipsis)),
          _VerifyBadge(status: q.verifyStatus),
        ]),
        const SizedBox(height: 12),
        Text(q.question, style: t.textTheme.titleLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) _option(_orders[_index][i], String.fromCharCode(65 + i), t),
        if (answered) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_chosen == q.answer ? 'Resposta correta!' : 'Resposta: ${q.correctOption}',
                    style: t.textTheme.titleMedium?.copyWith(
                        color: _chosen == q.answer ? Colors.green.shade700 : Colors.red.shade700)),
                const SizedBox(height: 8),
                Text(q.explanation),
                const SizedBox(height: 8),
                Text('Referência: ${q.refLabel}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.menu_book),
                    label: const Text('Ver na Bíblia'),
                    onPressed: () => openRef(context, q.refs.first),
                  ),
                ),
              ]),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _next,
            child: Text(_index + 1 >= widget.questions.length ? 'Ver resultado' : 'Próxima'),
          ),
        ],
      ]),
    );
  }

  Widget _option(int original, String letter, ThemeData t) {
    final answered = _chosen != null;
    final isCorrect = original == _q.answer;
    Color? bg;
    if (answered && isCorrect) bg = Colors.green.withValues(alpha: 0.2);
    if (answered && original == _chosen && !isCorrect) bg = Colors.red.withValues(alpha: 0.2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: bg ?? t.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: answered ? null : () => _answer(original),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: AppColors.navy, foregroundColor: AppColors.gold, child: Text(letter)),
              const SizedBox(width: 12),
              Expanded(child: Text(_q.options[original], style: t.textTheme.bodyLarge)),
              if (answered && isCorrect) const Icon(Icons.check_circle, color: Colors.green),
              if (answered && original == _chosen && !isCorrect) const Icon(Icons.cancel, color: Colors.red),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context) {
    final total = widget.questions.length;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Icon(Icons.emoji_events, size: 72, color: AppColors.gold),
        Center(child: Text('$_correct de $total', style: t.textTheme.displaySmall)),
        Center(child: Text('${(100 * _correct / total).round()}% de acertos')),
        const SizedBox(height: 16),
        if (_wrong.isNotEmpty) ...[
          Text('Perguntas erradas', style: t.textTheme.titleMedium),
          for (final q in _wrong)
            ListTile(
              title: Text(q.question),
              subtitle: Text('Resposta: ${q.correctOption} · ${q.refLabel}'),
              onTap: () => openRef(context, q.refs.first),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.replay),
            label: const Text('Refazer as erradas'),
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => QuizPlayScreen(questions: [..._wrong]..shuffle(), difficulty: 'erradas'))),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Concluir')),
      ]),
    );
  }
}

class _VerifyBadge extends StatelessWidget {
  const _VerifyBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      'conferida' => (Icons.verified, Colors.green, 'Conferida no texto'),
      'divergente' => (Icons.report_outlined, Colors.orange, 'Conferir referência'),
      _ => (Icons.hourglass_empty, Colors.grey, 'Não conferida'),
    };
    return Tooltip(message: label, child: Icon(icon, color: color, size: 20));
  }
}
