import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content.dart';
import '../services/app_services.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'nav.dart';

/// Estudo do Dia: selecionado pela data local do celular.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, this.studyId});
  final int? studyId;

  /// Dia do ano (1–366) → estudo. Enquanto houver menos de 365 estudos, a
  /// lista é percorrida em ciclo (indicado na tela).
  static int indexForDate(DateTime d, int count) {
    final dayOfYear = d.difference(DateTime(d.year)).inDays;
    return dayOfYear % count;
  }

  static DailyStudyData todayStudy() {
    final list = App.I.studies;
    return list[indexForDate(DateTime.now(), list.length)];
  }

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late int _index;
  bool _fav = false;
  late final int _today = StudyScreen.indexForDate(DateTime.now(), App.I.studies.length);

  List<DailyStudyData> get _list => App.I.studies;
  DailyStudyData get _s => _list[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.studyId != null
        ? _list.indexWhere((s) => s.id == widget.studyId).clamp(0, _list.length - 1)
        : _today;
    _loadFav();
  }

  Future<void> _loadFav() async {
    final f = await App.I.user.isFavorite('study', '${_s.id}');
    if (mounted) setState(() => _fav = f);
  }

  void _go(int delta) {
    setState(() => _index = (_index + delta) % _list.length);
    _loadFav();
  }

  String _shareText() => '${_s.title}\n${_s.refLabel}\n\n${_s.reflection}\n\n'
      '(Reflexão autoral — Bíblia & Hinos CCB)';

  Future<void> _answer() async {
    final s = App.I.settings;
    final ctrls = [
      for (var i = 0; i < _s.questions.length; i++) TextEditingController(text: s.studyAnswer(_s.id, i)),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          Text('Suas respostas', style: Theme.of(ctx).textTheme.titleLarge),
          for (var i = 0; i < _s.questions.length; i++) ...[
            const SizedBox(height: 12),
            Text('${i + 1}. ${_s.questions[i]}'),
            TextField(controller: ctrls[i], maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              for (var i = 0; i < ctrls.length; i++) {
                s.setStudyAnswer(_s.id, i, ctrls[i].text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = _s;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estudo do Dia'),
        actions: [
          IconButton(
            tooltip: 'Favorito',
            icon: Icon(_fav ? Icons.star : Icons.star_border, color: AppColors.gold),
            onPressed: () async {
              final v = await App.I.user.toggleFavorite('study', '${s.id}', s.title);
              setState(() => _fav = v);
            },
          ),
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.share),
            onPressed: () => SharePlus.instance.share(ShareParams(text: _shareText())),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(children: [
          TextButton.icon(onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left), label: const Text('Anterior')),
          Expanded(
            child: Text(_index == _today ? 'Hoje' : 'Estudo ${s.id}', textAlign: TextAlign.center),
          ),
          TextButton.icon(onPressed: () => _go(1), icon: const Icon(Icons.chevron_right), label: const Text('Próximo')),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(s.theme.toUpperCase(), style: t.textTheme.labelLarge?.copyWith(color: AppColors.gold, letterSpacing: 1.5)),
        Text(s.title, style: t.textTheme.headlineSmall),
        Text('Estudo ${s.id} de ${_list.length} (em ciclo enquanto a coleção não chega a 365)',
            style: t.textTheme.labelSmall),
        const SizedBox(height: 16),
        const SourceTag(biblical: true),
        for (final r in s.refs) PassageView(r),
        const SizedBox(height: 16),
        const SourceTag(biblical: false),
        Text('Contexto', style: t.textTheme.titleMedium),
        Text(s.context, style: t.textTheme.bodyLarge?.copyWith(height: 1.5)),
        const SizedBox(height: 12),
        Text('Reflexão', style: t.textTheme.titleMedium),
        Text(s.reflection, style: t.textTheme.bodyLarge?.copyWith(height: 1.5)),
        const SizedBox(height: 12),
        Text('Para pensar', style: t.textTheme.titleMedium),
        for (var i = 0; i < s.questions.length; i++)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('${i + 1}. ${s.questions[i]}')),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.menu_book),
              label: const Text('Ler na Bíblia'),
              onPressed: () => openRef(context, s.refs.first),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Responder'),
              onPressed: _answer,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Text('As explicações são autorais e não constituem ensinamento oficial da CCB.',
            style: t.textTheme.bodySmall),
      ]),
    );
  }
}
