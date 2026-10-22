import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/bible_ref.dart';
import '../data/agenda_repository.dart';
import '../data/places_repository.dart';
import '../data/youth_repository.dart';
import '../services/app_reminders.dart';
import '../services/app_services.dart';
import '../services/bible_audio.dart';
import '../services/reminders.dart';
import '../services/share_builders.dart' show shareFooter;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/share_card.dart';
import 'agenda_screen.dart';
import 'nav.dart';
import 'verse_image_screen.dart';

const String _templateKey = 'rjmTemplate';
const String _rjmKind = 'Reunião de Jovens e Menores';

bool _isRjm(String kind) => kind.toLowerCase().contains('jovens');

/// Área de Jovens: lembretes das reuniões, recitativos e roteiro do auxiliar.
class YouthScreen extends StatefulWidget {
  const YouthScreen({super.key});
  @override
  State<YouthScreen> createState() => _YouthScreenState();
}

class _YouthScreenState extends State<YouthScreen> {
  SavedPlace? _home;
  List<AgendaEvent> _rjmEvents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await App.I.places.home();
    final ev = [for (final e in await App.I.agenda.all()) if (_isRjm(e.kind)) e];
    if (mounted) {
      setState(() {
        _home = h;
        _rjmEvents = ev;
      });
    }
  }

  /// Cria lembretes semanais das RJM da comum (a partir dos horários do relatório).
  Future<void> _createFromHome() async {
    final h = _home;
    final times = [for (final c in h?.cultos ?? const <CultoTime>[]) if (_isRjm(c.kind)) c];
    if (h == null || times.isEmpty) {
      showSnack(context, 'Defina sua comum em "Minha comum" (com horários de RJM) ou crie o lembrete manualmente.');
      return;
    }
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Avisar antes'),
        children: [
          for (final e in alertOptions.entries)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e.key), child: Text(e.value)),
        ],
      ),
    );
    if (minutes == null) return;
    await CultoReminders.instance.requestPermission();
    final now = DateTime.now();
    var created = 0;
    for (final c in times) {
      final start = c.nextAfter(now);
      final exists = _rjmEvents.any((e) =>
          e.repeat == 'weekly' && e.start.weekday == c.weekday && e.start.hour == c.hour && e.start.minute == c.minute);
      if (exists) continue;
      await App.I.agenda.save(AgendaEvent(
          kind: _rjmKind, start: start, place: h.place.name, repeat: 'weekly', alerts: [minutes]));
      created++;
    }
    await refreshReminders();
    await _load();
    if (mounted) showSnack(context, created == 0 ? 'Os lembretes já existiam.' : '$created lembrete(s) criado(s) na agenda.');
  }

  @override
  Widget build(BuildContext context) {
    final rjmTimes = [for (final c in _home?.cultos ?? const <CultoTime>[]) if (_isRjm(c.kind)) c];
    return Scaffold(
      appBar: AppBar(title: const Text('Jovens')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: AppColors.navy, foregroundColor: AppColors.gold, child: Icon(Icons.checklist)),
            title: const Text('Andamento da reunião', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Roteiro para o auxiliar: hinos, oração, fila de recitativos e tempo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(context, const RjmRunScreen()),
          ),
        ),
        Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: AppColors.navy, foregroundColor: AppColors.gold, child: Icon(Icons.record_voice_over)),
            title: const Text('Recitativos', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Guardar, treinar e ouvir os recitativos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(context, const RecitativosScreen()),
          ),
        ),
        const SectionTitle('Lembretes das reuniões'),
        if (rjmTimes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('RJM na sua comum (${_home!.place.name}): ${rjmTimes.map((c) => '${c.dayName} ${c.time}').join(', ')}'),
          ),
        for (final e in _rjmEvents)
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined, color: AppColors.gold),
              title: Text(e.displayTitle),
              subtitle: Text([
                if (e.repeat == 'weekly') 'Toda ${weekdayLong[e.start.weekday - 1]} às ${hhmm(e.start)}' else shortDateTime(e.start),
                if (e.place.isNotEmpty) e.place,
                alertsLabel(e.alerts),
              ].join(' · ')),
              onTap: () async {
                final saved = await push<bool>(context, EventEditScreen(event: e));
                if (saved ?? false) {
                  await refreshReminders();
                  _load();
                }
              },
            ),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.home_outlined),
            label: const Text('Lembretes das RJM da minha comum'),
            onPressed: _createFromHome,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('Outro lembrete'),
            onPressed: () async {
              final saved = await push<bool>(context, const EventEditScreen(initialKind: _rjmKind));
              if (saved ?? false) {
                await refreshReminders();
                _load();
              }
            },
          ),
        ]),
      ]),
    );
  }
}

// ======================================================================= recitativos

class RecitativosScreen extends StatefulWidget {
  const RecitativosScreen({super.key});
  @override
  State<RecitativosScreen> createState() => _RecitativosScreenState();
}

class _RecitativosScreenState extends State<RecitativosScreen> {
  List<Recitativo>? _list;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await App.I.youth.recitativos();
    if (mounted) setState(() => _list = l);
  }

  Future<void> _add() async {
    final r = await showModalBottomSheet<Recitativo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RecitEditor(),
    );
    if (r == null) return;
    await App.I.youth.saveRecitativo(r);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = [for (final r in _list ?? const <Recitativo>[]) if (_filter == null || r.status == _filter) r];
    return Scaffold(
      appBar: AppBar(title: const Text('Recitativos')),
      floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.add), label: const Text('Novo'), onPressed: _add),
      body: _list == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
              Wrap(spacing: 6, children: [
                ChoiceChip(label: const Text('Todos'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                for (final e in recitStatus.entries)
                  ChoiceChip(label: Text(e.value), selected: _filter == e.key, onSelected: (_) => setState(() => _filter = e.key)),
              ]),
              if (l.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhum recitativo. Toque em "Novo" e digite a referência (ex.: Salmos 23:1-3).',
                      textAlign: TextAlign.center),
                ),
              for (final r in l)
                Card(
                  child: ListTile(
                    leading: Icon(
                      r.status == 'recitado' ? Icons.check_circle : r.status == 'pronto' ? Icons.star : Icons.menu_book_outlined,
                      color: r.status == 'decorar' ? AppColors.navy : r.status == 'pronto' ? AppColors.gold : Colors.green,
                    ),
                    title: Text(r.ref, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (r.person.isNotEmpty) r.person,
                      recitStatus[r.status] ?? r.status,
                      if (r.recitedAt != null) 'em ${two(r.recitedAt!.day)}/${two(r.recitedAt!.month)}/${r.recitedAt!.year}',
                    ].join(' · ')),
                    onTap: () async {
                      await push(context, RecitativoScreen(recit: r));
                      _load();
                    },
                  ),
                ),
            ]),
    );
  }
}

/// Digitar quem e a referência; o texto vem da Bíblia do app.
class _RecitEditor extends StatefulWidget {
  const _RecitEditor();
  @override
  State<_RecitEditor> createState() => _RecitEditorState();
}

class _RecitEditorState extends State<_RecitEditor> {
  final _person = TextEditingController();
  final _ref = TextEditingController();
  String _text = '';
  String? _label;
  String? _error;

  Future<void> _lookup() async {
    final ref = BibleRef.tryParse(_ref.text);
    if (ref == null || ref.verseStart == null) {
      setState(() => _error = 'Digite livro, capítulo e versículo(s). Ex.: Salmos 23:1-3');
      return;
    }
    if (!App.I.hasBibleText) {
      setState(() {
        _label = ref.label;
        _text = '';
        _error = 'A Bíblia ainda não foi preparada no app; o recitativo fica salvo só com a referência.';
      });
      return;
    }
    final vs = await App.I.bible.range(ref);
    setState(() {
      _label = ref.label;
      _text = vs.length == 1 ? vs.first.text : vs.map((v) => '${v.verse} ${v.text}').join(' ');
      _error = vs.isEmpty ? 'Versículo não encontrado.' : null;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Novo recitativo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _person,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Quem vai recitar (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ref,
              onSubmitted: (_) => _lookup(),
              decoration: InputDecoration(
                labelText: 'Referência',
                hintText: 'Ex.: Salmos 23:1-3',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _lookup, tooltip: 'Buscar texto'),
              ),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!)),
            if (_text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_text, style: const TextStyle(fontFamily: 'serif', fontSize: 16, height: 1.4)),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Salvar'),
              onPressed: _label == null
                  ? null
                  : () => Navigator.pop(context, Recitativo(person: _person.text.trim(), ref: _label!, text: _text)),
            ),
          ]),
        ),
      );
}

/// Recitativo: texto grande, treino com primeiras letras, ouvir e marcar situação.
class RecitativoScreen extends StatefulWidget {
  const RecitativoScreen({super.key, required this.recit});
  final Recitativo recit;
  @override
  State<RecitativoScreen> createState() => _RecitativoScreenState();
}

class _RecitativoScreenState extends State<RecitativoScreen> {
  late Recitativo _r = widget.recit;
  bool _train = false;
  final _tts = FlutterTts();
  bool _ttsReady = false;

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!_ttsReady) {
      await VoicePrefs.apply(_tts, await SharedPreferences.getInstance());
      final p = await SharedPreferences.getInstance();
      await _tts.setSpeechRate(audioSpeeds[p.getString('audioSpeed') ?? '1x'] ?? 0.5);
      _ttsReady = true;
    }
    await _tts.stop();
    await _tts.speak('${_r.ref}. ${_r.text.replaceAll(RegExp(r'\b\d+\s'), '')}');
  }

  Future<void> _setStatus(String s) async {
    final r = Recitativo(
      id: _r.id, person: _r.person, ref: _r.ref, text: _r.text, status: s,
      recitedAt: s == 'recitado' ? DateTime.now() : null, notes: _r.notes,
    );
    await App.I.youth.saveRecitativo(r);
    setState(() => _r = r);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_r.ref),
          actions: [
            IconButton(
              tooltip: 'Imagem para compartilhar',
              icon: const Icon(Icons.image_outlined),
              onPressed: _r.text.isEmpty ? null : () => push(context, VerseImageScreen(text: _r.text, reference: '${_r.ref} (ARC)')),
            ),
            IconButton(
              tooltip: 'Apagar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await App.I.youth.removeRecitativo(_r.id!);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (_r.person.isNotEmpty) Text(_r.person, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [for (final e in recitStatus.entries) ButtonSegment(value: e.key, label: Text(e.value))],
            selected: {_r.status},
            onSelectionChanged: (v) => _setStatus(v.first),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _r.text.isEmpty ? 'Texto não disponível (a Bíblia ainda não foi preparada no app).' : _train ? firstLetters(_r.text) : _r.text,
                style: const TextStyle(fontFamily: 'serif', fontSize: 22, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilterChip(
              avatar: const Icon(Icons.psychology_alt_outlined, size: 18),
              label: const Text('Treinar (só primeiras letras)'),
              selected: _train,
              onSelected: _r.text.isEmpty ? null : (v) => setState(() => _train = v),
            ),
            ActionChip(
              avatar: const Icon(Icons.volume_up, size: 18),
              label: const Text('Ouvir'),
              onPressed: _r.text.isEmpty ? null : _listen,
            ),
          ]),
        ]),
      );
}

// ======================================================================= andamento da reunião

Future<List<String>> _loadTemplate() async {
  final raw = (await SharedPreferences.getInstance()).getString(_templateKey);
  return raw == null ? defaultRjmTemplate : [for (final s in jsonDecode(raw) as List) '$s'];
}

ShareCardData rjmShare(RjmSession s) => ShareCardData(
      kicker: _rjmKind,
      title: s.place.isEmpty ? 'Reunião de Jovens' : s.place,
      subtitle: '${longDate(s.at)} · ${hhmm(s.at)}',
      icon: Icons.groups,
      sections: [
        ShareSection(title: 'Andamento', rows: [
          for (final st in s.steps) (st.title, st.detail),
        ]),
        if (s.recits.isNotEmpty)
          ShareSection(title: 'Recitativos', total: '${s.recits.length}', rows: [
            for (final r in s.recits) (r.person.isEmpty ? r.ref : r.person, r.person.isEmpty ? '' : r.ref),
          ]),
        if (s.notes.isNotEmpty) ShareSection(rows: [(s.notes, '')]),
      ],
      footer: shareFooter,
    );

/// Roteiro da reunião para o auxiliar de jovens.
class RjmRunScreen extends StatefulWidget {
  const RjmRunScreen({super.key, this.session});
  final RjmSession? session;
  @override
  State<RjmRunScreen> createState() => _RjmRunScreenState();
}

class _RjmRunScreenState extends State<RjmRunScreen> {
  RjmSession? _s;
  Timer? _tick;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_s?.startedAt != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    var s = widget.session;
    if (s == null) {
      // Continua a reunião de hoje, se houver; senão começa uma nova pelo modelo.
      final today = DateTime.now();
      s = (await App.I.youth.sessions()).where((x) => DateUtils.isSameDay(x.at, today)).firstOrNull;
      if (s == null) {
        final home = await App.I.places.home();
        s = RjmSession(
          at: today,
          place: home?.place.name ?? '',
          steps: [for (final t in await _loadTemplate()) RjmStep(t)],
        );
      }
    }
    if (mounted) {
      _notes.text = s.notes;
      setState(() => _s = s);
    }
  }

  Future<void> _save() async {
    final s = _s;
    if (s != null) await App.I.youth.saveSession(s);
  }

  void _update(VoidCallback f) {
    setState(f);
    _save();
  }

  String get _elapsed {
    final st = _s?.startedAt;
    if (st == null) return '00:00';
    final d = DateTime.now().difference(st);
    return '${two(d.inHours > 0 ? d.inHours * 60 + d.inMinutes % 60 : d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  Future<String?> _ask(String title, {String initial = '', String hint = '', TextInputType? type}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: type,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _editStep(RjmStep st) async {
    final v = await _ask(st.title,
        initial: st.detail,
        hint: st.title.toLowerCase().contains('hino') ? 'Número do hino' : 'Quem / observação',
        type: st.title.toLowerCase().contains('hino') ? TextInputType.number : null);
    if (v != null) _update(() => st.detail = v);
  }

  Future<void> _addRecit() async {
    final saved = [for (final r in await App.I.youth.recitativos()) if (r.status != 'recitado') r];
    if (!mounted) return;
    final choice = await showModalBottomSheet<RjmRecit>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(shrinkWrap: true, children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Digitar nome e referência'),
          onTap: () => Navigator.pop(ctx, RjmRecit('', '')),
        ),
        if (saved.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Recitativos guardados')),
        for (final r in saved)
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: Text(r.ref),
            subtitle: r.person.isEmpty ? null : Text(r.person),
            onTap: () => Navigator.pop(ctx, RjmRecit(r.person, r.ref)),
          ),
      ]),
    );
    if (choice == null) return;
    if (choice.ref.isEmpty) {
      final person = await _ask('Quem vai recitar', hint: 'Nome');
      if (person == null) return;
      final ref = await _ask('Referência', hint: 'Ex.: Salmos 23:1');
      if (ref == null) return;
      choice
        ..person = person
        ..ref = BibleRef.tryParse(ref)?.label ?? ref;
    }
    _update(() => _s!.recits.add(choice));
  }

  Future<void> _editTemplate() async {
    final steps = await _loadTemplate();
    if (!mounted) return;
    final t = await push<List<String>>(context, _TemplateEditor(steps: steps));
    if (t == null) return;
    (await SharedPreferences.getInstance()).setString(_templateKey, jsonEncode(t));
    if (mounted) showSnack(context, 'Modelo salvo. Vale para as próximas reuniões.');
  }

  Future<void> _newSession() async {
    final home = await App.I.places.home();
    final steps = [for (final t in await _loadTemplate()) RjmStep(t)];
    _notes.clear();
    setState(() => _s = RjmSession(at: DateTime.now(), place: home?.place.name ?? '', steps: steps));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final next = s.steps.indexWhere((x) => !x.done);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Andamento da reunião'),
        actions: [
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.share),
            onPressed: () async {
              await _save();
              if (context.mounted) push(context, ShareCardScreen(data: rjmShare(s), title: 'Compartilhar reunião'));
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'new' => _newSession(),
              'history' => push(context, const _RjmHistory()),
              _ => _editTemplate(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'new', child: Text('Nova reunião')),
              PopupMenuItem(value: 'history', child: Text('Reuniões anteriores')),
              PopupMenuItem(value: 'template', child: Text('Editar modelo do roteiro')),
            ],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 32), children: [
        Card(
          color: AppColors.navy,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InkWell(
                    onTap: () async {
                      final v = await _ask('Comum', initial: s.place);
                      if (v != null) _update(() => s.place = v);
                    },
                    child: Text(s.place.isEmpty ? 'Toque para informar a comum' : s.place,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  Text('${two(s.at.day)}/${two(s.at.month)}/${s.at.year} · ${s.done} de ${s.steps.length} partes',
                      style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              Column(children: [
                Text(_elapsed, style: const TextStyle(color: AppColors.gold, fontSize: 26, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => _update(() => s.startedAt = s.startedAt == null ? DateTime.now() : null),
                  child: Text(s.startedAt == null ? 'Iniciar' : 'Zerar', style: const TextStyle(color: Colors.white)),
                ),
              ]),
            ]),
          ),
        ),
        Text('Roteiro de exemplo, editável no menu ⋮ conforme a orientação da sua comum.',
            style: Theme.of(context).textTheme.bodySmall),
        for (var i = 0; i < s.steps.length; i++)
          Card(
            color: i == next ? AppColors.gold.withValues(alpha: 0.25) : null,
            child: CheckboxListTile(
              value: s.steps[i].done,
              onChanged: (v) => _update(() => s.steps[i].done = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(s.steps[i].title, style: TextStyle(fontWeight: i == next ? FontWeight.bold : null)),
              subtitle: Text(s.steps[i].detail.isEmpty
                  ? (s.steps[i].title.toLowerCase().contains('hino') ? 'Toque no lápis para informar o hino' : 'Toque no lápis para anotar')
                  : s.steps[i].title.toLowerCase().contains('hino') && s.steps[i].hymnNumber != null
                      ? 'Hino ${s.steps[i].hymnNumber}'
                      : s.steps[i].detail),
              secondary: Row(mainAxisSize: MainAxisSize.min, children: [
                if (s.steps[i].hymnNumber != null)
                  IconButton(
                    tooltip: 'Abrir hino',
                    icon: const Icon(Icons.library_music_outlined),
                    onPressed: () => openHymn(context, s.steps[i].hymnNumber!),
                  ),
                IconButton(tooltip: 'Anotar', icon: const Icon(Icons.edit_outlined), onPressed: () => _editStep(s.steps[i])),
              ]),
            ),
          ),
        const SectionTitle('Recitativos da reunião'),
        for (var i = 0; i < s.recits.length; i++)
          Card(
            child: CheckboxListTile(
              value: s.recits[i].done,
              onChanged: (v) => _update(() => s.recits[i].done = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('${i + 1}. ${s.recits[i].person.isEmpty ? s.recits[i].ref : s.recits[i].person}'),
              subtitle: s.recits[i].person.isEmpty ? null : Text(s.recits[i].ref),
              secondary: IconButton(
                tooltip: 'Tirar da lista',
                icon: const Icon(Icons.close),
                onPressed: () => _update(() => s.recits.removeAt(i)),
              ),
            ),
          ),
        Row(children: [
          OutlinedButton.icon(icon: const Icon(Icons.person_add_alt), label: const Text('Adicionar recitativo'), onPressed: _addRecit),
          const Spacer(),
          if (s.recits.isNotEmpty)
            Text('${s.recits.where((r) => r.done).length} de ${s.recits.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 2,
          onChanged: (v) => s.notes = v,
          onEditingComplete: _save,
          decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder()),
        ),
      ]),
    );
  }
}

class _RjmHistory extends StatefulWidget {
  const _RjmHistory();
  @override
  State<_RjmHistory> createState() => _RjmHistoryState();
}

class _RjmHistoryState extends State<_RjmHistory> {
  List<RjmSession>? _l;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await App.I.youth.sessions();
    if (mounted) setState(() => _l = l);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reuniões anteriores')),
        body: _l == null
            ? const Center(child: CircularProgressIndicator())
            : _l!.isEmpty
                ? const EmptyState(icon: Icons.history, title: 'Nenhuma reunião salva')
                : ListView(padding: const EdgeInsets.all(12), children: [
                    for (final s in _l!)
                      Card(
                        child: ListTile(
                          title: Text(s.place.isEmpty ? 'Reunião de Jovens' : s.place),
                          subtitle: Text('${two(s.at.day)}/${two(s.at.month)}/${s.at.year} · ${s.recits.length} recitativo(s)'),
                          onTap: () => push(context, RjmRunScreen(session: s)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'share') {
                                push(context, ShareCardScreen(data: rjmShare(s)));
                              } else {
                                await App.I.youth.removeSession(s.id!);
                                _load();
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'share', child: Text('Compartilhar')),
                              PopupMenuItem(value: 'remove', child: Text('Apagar')),
                            ],
                          ),
                        ),
                      ),
                  ]),
      );
}

/// Edita as partes do roteiro (modelo para as próximas reuniões).
class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({required this.steps});
  final List<String> steps;
  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final List<String> _s = [...widget.steps];

  Future<void> _add([int? at]) async {
    final c = TextEditingController(text: at == null ? '' : _s[at]);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(at == null ? 'Nova parte' : 'Renomear parte'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK'))],
      ),
    );
    if (v == null || v.isEmpty) return;
    setState(() => at == null ? _s.add(v) : _s[at] = v);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Modelo do roteiro'),
          actions: [
            TextButton(
              onPressed: () => setState(() => _s
                ..clear()
                ..addAll(defaultRjmTemplate)),
              child: const Text('Exemplo'),
            ),
            TextButton(onPressed: () => Navigator.pop(context, _s), child: const Text('Salvar')),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.add), label: const Text('Parte'), onPressed: _add),
        body: ReorderableListView(
          padding: const EdgeInsets.only(bottom: 96),
          onReorderItem: (a, b) => setState(() => _s.insert(b, _s.removeAt(a))),
          children: [
            for (var i = 0; i < _s.length; i++)
              ListTile(
                key: ValueKey('$i-${_s[i]}'),
                leading: const Icon(Icons.drag_handle),
                title: Text(_s[i]),
                onTap: () => _add(i),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _s.removeAt(i))),
              ),
          ],
        ),
      );
}
