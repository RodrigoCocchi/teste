import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/agenda_repository.dart' show alertOptions, alertsLabel;
import '../data/organ_repository.dart';
import '../data/places_repository.dart';
import '../services/app_reminders.dart';
import '../services/app_services.dart';
import '../services/reminders.dart';
import '../services/share_builders.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/share_card.dart';
import 'nav.dart';

/// Escala (rodízio) das organistas: cadastro, geração do mês, lembretes e compartilhar.
class OrganScreen extends StatefulWidget {
  const OrganScreen({super.key});
  @override
  State<OrganScreen> createState() => _OrganScreenState();
}

class _OrganScreenState extends State<OrganScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Organist> _organists = [];
  List<OrganDuty> _duties = [];
  bool _onlyMine = false;
  List<int> _alerts = const [1440, 120];

  Map<int, String> get _names => {for (final o in _organists) o.id: o.name};
  Organist? get _me => _organists.where((o) => o.isMe).firstOrNull;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => _alerts = organAlertsFrom(p)));
    _load();
  }

  Future<void> _load() async {
    final repo = App.I.organ;
    final o = await repo.organists();
    final d = await repo.duties(from: _month, to: DateTime(_month.year, _month.month + 1));
    if (mounted) {
      setState(() {
        _organists = o;
        _duties = d;
      });
    }
  }

  Future<void> _changed() async {
    await _load();
    await refreshReminders();
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  String get _monthLabel {
    final m = monthNames[_month.month - 1];
    return '${m[0].toUpperCase()}${m.substring(1)} de ${_month.year}';
  }

  // ---------------------------------------------------------------- organistas

  Future<String?> _nameDialog(String title, [String initial = '']) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nome da organista'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Salvar')),
        ],
      ),
    );
  }

  Future<void> _addOrganist() async {
    final n = await _nameDialog('Nova organista');
    if (n == null || n.trim().isEmpty) return;
    await App.I.organ.addOrganist(n);
    _changed();
  }

  Widget _organistsTab() => _organists.isEmpty
      ? EmptyState(
          icon: Icons.group_add_outlined,
          title: 'Cadastre as organistas',
          message: 'Adicione as organistas da comum na ordem do rodízio e marque qual é você para receber os lembretes.',
          action: FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Adicionar'), onPressed: _addOrganist),
        )
      : Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Arraste para mudar a ordem do rodízio. Toque na estrela para marcar quem é você.'),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.only(bottom: 96),
              onReorderItem: (a, b) async {
                final ids = [for (final o in _organists) o.id];
                final id = ids.removeAt(a);
                ids.insert(b, id);
                await App.I.organ.reorder(ids);
                _load();
              },
              children: [
                for (final o in _organists)
                  ListTile(
                    key: ValueKey(o.id),
                    leading: IconButton(
                      tooltip: o.isMe ? 'Sou eu' : 'Marcar como eu',
                      icon: Icon(o.isMe ? Icons.star : Icons.star_border, color: o.isMe ? AppColors.gold : null),
                      onPressed: () async {
                        await App.I.organ.setMe(o.isMe ? null : o.id);
                        if (!o.isMe) await CultoReminders.instance.requestPermission();
                        _changed();
                      },
                    ),
                    title: Text(o.name),
                    subtitle: o.isMe ? const Text('Eu · recebo os lembretes') : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'rename') {
                          final n = await _nameDialog('Renomear', o.name);
                          if (n != null && n.trim().isNotEmpty) await App.I.organ.renameOrganist(o.id, n);
                        } else {
                          await App.I.organ.removeOrganist(o.id);
                        }
                        _changed();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Renomear')),
                        PopupMenuItem(value: 'remove', child: Text('Remover')),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ]);

  // ---------------------------------------------------------------- escala

  Future<void> _editAlerts() async {
    final sel = {..._alerts};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Avisar antes de tocar'),
          content: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final e in alertOptions.entries)
              FilterChip(
                label: Text(e.value),
                selected: sel.contains(e.key),
                onSelected: (s) => setLocal(() => s ? sel.add(e.key) : sel.remove(e.key)),
              ),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK'))],
        ),
      ),
    );
    if (ok != true) return;
    final list = sel.toList()..sort();
    (await SharedPreferences.getInstance()).setStringList(organAlertsKey, [for (final m in list) '$m']);
    setState(() => _alerts = list);
    await refreshReminders();
  }

  Future<void> _editDuty([OrganDuty? d]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DutyEditor(duty: d, organists: _organists, month: _month),
    );
    if (saved ?? false) _changed();
  }

  Future<void> _generate() async {
    if (_organists.isEmpty) {
      showSnack(context, 'Cadastre as organistas primeiro (aba "Organistas").');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _Generator(organists: _organists, month: _month, hasDuties: _duties.isNotEmpty),
    );
    if (saved ?? false) _changed();
  }

  void _shareMonth() {
    final list = _onlyMine && _me != null ? _duties.where((d) => d.organistId == _me!.id).toList() : _duties;
    if (list.isEmpty) {
      showSnack(context, 'Nada para compartilhar neste mês.');
      return;
    }
    final places = {for (final d in list) d.place}..remove('');
    push(context, ShareCardScreen(
      data: monthScaleShare(list, _names, _month.year, _month.month, places.length == 1 ? places.first : ''),
      title: 'Escala do mês',
    ));
  }

  Widget _scaleTab() {
    final me = _me;
    final list = _onlyMine && me != null ? _duties.where((d) => d.organistId == me.id).toList() : _duties;
    final byDay = <DateTime, List<OrganDuty>>{};
    for (final d in list) {
      byDay.putIfAbsent(DateTime(d.at.year, d.at.month, d.at.day), () => []).add(d);
    }
    final today = DateTime.now();
    return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 96), children: [
      Row(children: [
        IconButton(onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Mês anterior'),
        Expanded(child: Text(_monthLabel, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
        IconButton(onPressed: () => _moveMonth(1), icon: const Icon(Icons.chevron_right), tooltip: 'Próximo mês'),
      ]),
      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (me != null)
          FilterChip(
            label: const Text('Só as minhas'),
            selected: _onlyMine,
            onSelected: (v) => setState(() => _onlyMine = v),
          ),
        ActionChip(
          avatar: const Icon(Icons.notifications_active_outlined, size: 18),
          label: Text('Avisos: ${alertsLabel(_alerts)}'),
          onPressed: _editAlerts,
        ),
      ]),
      if (me == null && _organists.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Para receber lembretes, marque quem é você na aba "Organistas".'),
        ),
      if (list.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhuma escala neste mês. Toque em "Gerar rodízio" ou adicione manualmente.',
              textAlign: TextAlign.center),
        ),
      for (final e in byDay.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            '${two(e.key.day)}/${two(e.key.month)} · ${weekdayLong[e.key.weekday - 1]}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: DateUtils.isSameDay(e.key, today) ? AppColors.gold : AppColors.navy,
            ),
          ),
        ),
        for (final d in e.value)
          Card(
            child: ListTile(
              leading: Icon(Icons.piano, color: d.organistId != null && d.organistId == me?.id ? AppColors.gold : AppColors.navy),
              title: Text(d.organistId == null ? 'Sem organista' : _names[d.organistId] ?? 'Sem organista'),
              subtitle: Text([dutyLine(d), if (d.place.isNotEmpty) d.place].join('\n')),
              onTap: () => _editDuty(d),
              trailing: IconButton(
                tooltip: 'Compartilhar',
                icon: const Icon(Icons.share),
                onPressed: () => push(context, ShareCardScreen(data: dutyShare(d, _names[d.organistId] ?? ''))),
              ),
            ),
          ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Builder(builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Escala das organistas'),
              actions: [IconButton(tooltip: 'Compartilhar o mês', icon: const Icon(Icons.share), onPressed: _shareMonth)],
              bottom: const TabBar(tabs: [Tab(text: 'Escala'), Tab(text: 'Organistas')]),
            ),
            floatingActionButton: _Fab(
              onAddOrganist: _addOrganist,
              onAddDuty: () => _editDuty(),
              onGenerate: _generate,
            ),
            body: TabBarView(children: [_scaleTab(), _organistsTab()]),
          );
        }),
      );
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onAddOrganist, required this.onAddDuty, required this.onGenerate});
  final VoidCallback onAddOrganist, onAddDuty, onGenerate;

  @override
  Widget build(BuildContext context) {
    final tab = DefaultTabController.of(context);
    return ListenableBuilder(
      listenable: tab,
      builder: (context, _) => tab.index == 1
          ? FloatingActionButton.extended(icon: const Icon(Icons.person_add), label: const Text('Organista'), onPressed: onAddOrganist)
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              FloatingActionButton.small(heroTag: 'add', tooltip: 'Adicionar na escala', onPressed: onAddDuty, child: const Icon(Icons.add)),
              const SizedBox(height: 10),
              FloatingActionButton.extended(
                heroTag: 'gen',
                icon: const Icon(Icons.autorenew),
                label: const Text('Gerar rodízio'),
                onPressed: onGenerate,
              ),
            ]),
    );
  }
}

/// Editar um compromisso da escala.
class _DutyEditor extends StatefulWidget {
  const _DutyEditor({this.duty, required this.organists, required this.month});
  final OrganDuty? duty;
  final List<Organist> organists;
  final DateTime month;
  @override
  State<_DutyEditor> createState() => _DutyEditorState();
}

class _DutyEditorState extends State<_DutyEditor> {
  late DateTime _at = widget.duty?.at ?? DateTime(widget.month.year, widget.month.month, 1, 19, 30);
  late String _part = widget.duty?.part ?? organParts.first;
  late int? _organist = widget.duty?.organistId ?? widget.organists.firstOrNull?.id;
  late final _place = TextEditingController(text: widget.duty?.place ?? '');
  late final _notes = TextEditingController(text: widget.duty?.notes ?? '');

  @override
  void initState() {
    super.initState();
    if (widget.duty == null) {
      App.I.places.home().then((h) {
        if (h != null && _place.text.isEmpty && mounted) setState(() => _place.text = h.place.name);
      });
    }
  }

  Future<void> _save() async {
    await App.I.organ.saveDuty(OrganDuty(
        id: widget.duty?.id, at: _at, part: _part, organistId: _organist, place: _place.text.trim(), notes: _notes.text.trim()));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.duty == null ? 'Adicionar na escala' : 'Editar escala', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text('${two(_at.day)}/${two(_at.month)}/${_at.year}'),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: _at, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (d != null) setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text('Culto ${hhmm(_at)}'),
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
                    if (t != null) setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _part,
              decoration: const InputDecoration(labelText: 'Parte', border: OutlineInputBorder()),
              items: [for (final p in organParts) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) => setState(() => _part = v ?? _part),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _organist,
              decoration: const InputDecoration(labelText: 'Organista', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Sem organista')),
                for (final o in widget.organists) DropdownMenuItem<int?>(value: o.id, child: Text(o.name)),
              ],
              onChanged: (v) => setState(() => _organist = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _place, decoration: const InputDecoration(labelText: 'Comum (local)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Observação', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(children: [
              if (widget.duty != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Apagar'),
                  onPressed: () async {
                    await App.I.organ.removeDuty(widget.duty!.id!);
                    if (context.mounted) Navigator.pop(context, true);
                  },
                ),
              const Spacer(),
              FilledButton.icon(icon: const Icon(Icons.check), label: const Text('Salvar'), onPressed: _save),
            ]),
          ]),
        ),
      );
}

/// Gerar o rodízio do mês a partir dos horários de culto.
class _Generator extends StatefulWidget {
  const _Generator({required this.organists, required this.month, required this.hasDuties});
  final List<Organist> organists;
  final DateTime month;
  final bool hasDuties;
  @override
  State<_Generator> createState() => _GeneratorState();
}

class _GeneratorState extends State<_Generator> {
  List<SavedPlace> _places = [];
  SavedPlace? _place;
  final Set<CultoTime> _times = {};
  // Horários manuais (quando não há casa salva): (dia da semana, hora, minuto).
  final Set<(int, int, int)> _manual = {};
  late final Set<int> _who = {for (final o in widget.organists) o.id};
  bool _split = false;
  bool _replace = true;
  int _start = 0;

  @override
  void initState() {
    super.initState();
    App.I.places.all().then((ps) {
      if (!mounted) return;
      setState(() {
        _places = ps;
        _selectPlace(ps.where((p) => p.isHome).firstOrNull ?? ps.firstOrNull);
      });
    });
    SharedPreferences.getInstance().then((p) {
      final next = p.getInt('organNext') ?? 0;
      if (mounted) setState(() => _start = next % (widget.organists.isEmpty ? 1 : widget.organists.length));
    });
  }

  void _selectPlace(SavedPlace? p) {
    _place = p;
    _times
      ..clear()
      ..addAll((p?.cultos ?? const []).where((c) => c.kind.toLowerCase().contains('oficial')));
  }

  List<(int, int, int)> get _weekly => [
        for (final c in _times) (c.weekday, c.hour, c.minute),
        ..._manual,
      ];

  Future<void> _addManual() async {
    var wd = DateTime.sunday;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Dia do culto'),
          content: Wrap(spacing: 6, children: [
            for (var d = 1; d <= 7; d++)
              ChoiceChip(label: Text(weekdayNames[d - 1]), selected: wd == d, onSelected: (_) => setLocal(() => wd = d)),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Escolher horário'))],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 19, minute: 30));
    if (t != null) setState(() => _manual.add((wd, t.hour, t.minute)));
  }

  Future<void> _create() async {
    final ids = [for (final o in widget.organists) if (_who.contains(o.id)) o.id];
    final slots = monthSlots(widget.month.year, widget.month.month, _weekly);
    if (ids.isEmpty || slots.isEmpty) {
      showSnack(context, 'Escolha as organistas e os horários de culto.');
      return;
    }
    final (duties, next) = generateRotation(
        slots: slots, organistIds: ids, split: _split, startIndex: _start % ids.length, place: _place?.place.name ?? '');
    final repo = App.I.organ;
    if (_replace) await repo.clearMonth(widget.month.year, widget.month.month);
    await repo.saveDuties(duties);
    (await SharedPreferences.getInstance()).setInt('organNext', next);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final slots = monthSlots(widget.month.year, widget.month.month, _weekly);
    final cultos = _place?.cultos ?? const <CultoTime>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Gerar rodízio de ${monthNames[widget.month.month - 1]}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_places.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _place?.place.id,
              decoration: const InputDecoration(labelText: 'Comum', border: OutlineInputBorder()),
              items: [for (final p in _places) DropdownMenuItem(value: p.place.id, child: Text(p.place.name))],
              onChanged: (id) => setState(() => _selectPlace(_places.firstWhere((p) => p.place.id == id))),
            ),
            const SizedBox(height: 8),
            const Text('Cultos com órgão', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final c in cultos)
                FilterChip(
                  label: Text('${c.dayName} ${c.time}${c.kind.toLowerCase().contains('oficial') ? '' : ' · RJM'}'),
                  selected: _times.contains(c),
                  onSelected: (s) => setState(() => s ? _times.add(c) : _times.remove(c)),
                ),
            ]),
          ] else
            const Text('Dica: salve a sua comum em "Cultos perto de mim" para usar os horários do relatório.'),
          Wrap(spacing: 6, children: [
            for (final m in _manual)
              InputChip(
                label: Text('${weekdayNames[m.$1 - 1]} ${two(m.$2)}:${two(m.$3)}'),
                onDeleted: () => setState(() => _manual.remove(m)),
              ),
            ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Outro horário'), onPressed: _addManual),
          ]),
          const SizedBox(height: 12),
          const Text('Organistas no rodízio (na ordem cadastrada)', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final o in widget.organists)
              FilterChip(
                label: Text(o.name),
                selected: _who.contains(o.id),
                onSelected: (s) => setState(() => s ? _who.add(o.id) : _who.remove(o.id)),
              ),
          ]),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _start.clamp(0, widget.organists.length - 1),
            decoration: const InputDecoration(labelText: 'Começar por', border: OutlineInputBorder()),
            items: [
              for (var i = 0; i < widget.organists.length; i++)
                DropdownMenuItem(value: i, child: Text(widget.organists[i].name)),
            ],
            onChanged: (v) => setState(() => _start = v ?? 0),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Meia hora e culto com organistas diferentes'),
            subtitle: Text(_split ? 'Uma faz a meia hora, a seguinte faz o culto' : 'A mesma organista faz meia hora e culto'),
            value: _split,
            onChanged: (v) => setState(() => _split = v),
          ),
          if (widget.hasDuties)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Substituir a escala que já existe neste mês'),
              value: _replace,
              onChanged: (v) => setState(() => _replace = v),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.autorenew),
            label: Text('Gerar ${slots.length} culto(s)'),
            onPressed: _create,
          ),
        ]),
      ),
    );
  }
}
