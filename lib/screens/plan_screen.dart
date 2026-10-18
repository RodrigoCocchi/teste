import 'package:flutter/material.dart';

import '../core/bible_ref.dart';
import '../data/plan_repository.dart';
import '../data/reading_plan.dart';
import '../services/app_services.dart';
import '../theme.dart';
import 'nav.dart';

/// Plano anual: 1189 capítulos em 365 dias.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Map<PlanChapter, DateTime> _done = {};
  PlanProgress? _progress;
  final _scroll = ScrollController();
  bool _scrolled = false;

  PlanRepository get _repo => App.I.plan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final done = await _repo.done();
    if (!mounted) return;
    setState(() {
      _done = done;
      _progress = _repo.progressFrom(done);
    });
    if (!_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final next = _progress!.nextDay;
        if (_scroll.hasClients) _scroll.jumpTo(((next - 1) * 72.0).clamp(0, _scroll.position.maxScrollExtent));
      });
    }
  }

  Future<void> _toggle(PlanChapter c, bool v) async {
    await _repo.setDone(c, v);
    _load();
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recomeçar o plano?'),
        content: const Text('Todo o progresso marcado será apagado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Recomeçar')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.reset();
      _load();
    }
  }

  void _history() {
    final entries = _done.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => entries.isEmpty
          ? const SizedBox(height: 120, child: Center(child: Text('Nenhum capítulo concluído.')))
          : ListView(children: [
              for (final e in entries.take(200))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.check, color: Colors.green),
                  title: Text(e.key.label),
                  trailing: Text('${e.value.day.toString().padLeft(2, '0')}/${e.value.month.toString().padLeft(2, '0')}/${e.value.year}'),
                ),
            ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _repo.plan;
    final p = _progress;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano de Leitura'),
        actions: [
          IconButton(tooltip: 'Histórico', icon: const Icon(Icons.history), onPressed: _history),
          IconButton(tooltip: 'Recomeçar', icon: const Icon(Icons.restart_alt), onPressed: _reset),
        ],
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${(p.fraction * 100).toStringAsFixed(1)}% concluído',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: p.fraction, color: AppColors.gold, minHeight: 6),
                    const SizedBox(height: 6),
                    Text('${p.doneChapters} de ${p.totalChapters} capítulos · ${p.daysDone} de ${plan.length} dias'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Continuar: dia ${p.nextDay}'),
                      onPressed: () {
                        final next = plan[p.nextDay - 1].firstWhere((c) => !_done.containsKey(c),
                            orElse: () => plan[p.nextDay - 1].first);
                        openRef(context, _ref(next)).then((_) => _load());
                      },
                    ),
                  ]),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: plan.length,
                  itemExtent: 72,
                  itemBuilder: (_, d) {
                    final chapters = plan[d];
                    final complete = chapters.every(_done.containsKey);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: complete ? Colors.green : AppColors.navy,
                        foregroundColor: complete ? Colors.white : AppColors.gold,
                        child: complete ? const Icon(Icons.check) : Text('${d + 1}', style: const TextStyle(fontSize: 13)),
                      ),
                      title: Text('Dia ${d + 1}'),
                      subtitle: Text(_summary(chapters), maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _openDay(d),
                    );
                  },
                ),
              ),
            ]),
    );
  }

  static String _summary(List<PlanChapter> cs) {
    final first = cs.first, last = cs.last;
    if (first.bookId == last.bookId) return '${first.label}–${last.chapter}';
    return '${first.label} a ${last.label}';
  }

  static BibleRef _ref(PlanChapter c) => BibleRef(c.bookId, c.chapter);

  Future<void> _openDay(int d) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Dia ${d + 1}', style: Theme.of(ctx).textTheme.titleLarge),
            for (final c in _repo.plan[d])
              CheckboxListTile(
                value: _done.containsKey(c),
                title: Text(c.label),
                secondary: IconButton(
                  icon: const Icon(Icons.menu_book),
                  onPressed: () => openRef(context, _ref(c)),
                ),
                onChanged: (v) async {
                  await _toggle(c, v ?? false);
                  setLocal(() {});
                },
              ),
          ]),
        ),
      ),
    );
  }
}
