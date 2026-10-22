import 'package:flutter/material.dart';

import '../data/agenda_repository.dart';
import '../services/app_reminders.dart';
import '../services/app_services.dart';
import '../services/reminders.dart';
import '../services/share_builders.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/share_card.dart';
import 'nav.dart';

/// Agenda: ensaios, Santa Ceia, batismos e outros compromissos, com alertas.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  List<(AgendaEvent, DateTime)> _next = [];
  List<AgendaEvent> _past = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final all = await App.I.agenda.all();
    final next = <(AgendaEvent, DateTime)>[];
    final past = <AgendaEvent>[];
    for (final e in all) {
      final n = e.nextAfter(now.subtract(const Duration(hours: 3)));
      n == null ? past.add(e) : next.add((e, n));
    }
    next.sort((a, b) => a.$2.compareTo(b.$2));
    if (mounted) {
      setState(() {
        _next = next;
        _past = past.reversed.toList();
        _loading = false;
      });
    }
  }

  Future<void> _edit([AgendaEvent? e]) async {
    final saved = await push<bool>(context, EventEditScreen(event: e));
    if (saved ?? false) {
      await refreshReminders();
      _load();
    }
  }

  Widget _tile(AgendaEvent e, DateTime? at) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.gold,
            child: Icon(agendaIcon(e.kind)),
          ),
          title: Text(e.displayTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text([
            if (at != null) '${longDate(at)} · ${hhmm(at)}' else shortDateTime(e.start),
            if (e.place.isNotEmpty) e.place,
            '${repeatOptions[e.repeat]} · ${alertsLabel(e.alerts)}',
          ].join('\n')),
          isThreeLine: true,
          onTap: () => _edit(e),
          trailing: IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.share),
            onPressed: () => push(context, ShareCardScreen(data: eventShare(e, at ?? e.start))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Agenda')),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Novo'),
          onPressed: () => _edit(),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _next.isEmpty && _past.isEmpty
                ? const EmptyState(
                    icon: Icons.event_available,
                    title: 'Nenhum compromisso',
                    message: 'Toque em "Novo" para marcar ensaios, Santa Ceia, batismos e outros, '
                        'com alerta antes.',
                  )
                : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
                    if (_next.isNotEmpty) const SectionTitle('Próximos'),
                    for (final (e, at) in _next) _tile(e, at),
                    if (_past.isNotEmpty) const SectionTitle('Já passaram'),
                    for (final e in _past) _tile(e, null),
                  ]),
      );
}

/// Criar ou editar um compromisso.
class EventEditScreen extends StatefulWidget {
  const EventEditScreen({super.key, this.event, this.initialKind});
  final AgendaEvent? event;
  final String? initialKind;
  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  late String _kind = widget.event?.kind ?? widget.initialKind ?? agendaKinds.first.name;
  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _place = TextEditingController(text: widget.event?.place ?? '');
  late final _notes = TextEditingController(text: widget.event?.notes ?? '');
  late DateTime _start = widget.event?.start ?? _defaultStart();
  late String _repeat = widget.event?.repeat ?? 'none';
  late final Set<int> _alerts = {...(widget.event?.alerts ?? const [60, 1440])};
  List<String> _places = [];

  static DateTime _defaultStart() {
    final n = DateTime.now().add(const Duration(days: 1));
    return DateTime(n.year, n.month, n.day, 19, 30);
  }

  @override
  void initState() {
    super.initState();
    App.I.places.all().then((ps) {
      if (!mounted) return;
      setState(() => _places = [for (final p in ps) p.place.name]);
      if (widget.event == null && _place.text.isEmpty) {
        final home = ps.where((p) => p.isHome).firstOrNull;
        if (home != null) _place.text = home.place.name;
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (t != null) setState(() => _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_alerts.isNotEmpty && !await CultoReminders.instance.requestPermission()) {
      if (mounted) showSnack(context, 'Sem permissão de notificação: o compromisso fica salvo, mas sem alerta.');
    }
    await App.I.agenda.save(AgendaEvent(
      id: widget.event?.id,
      kind: _kind,
      title: _title.text,
      start: _start,
      place: _place.text.trim(),
      notes: _notes.text.trim(),
      repeat: _repeat,
      alerts: _alerts.toList()..sort(),
    ));
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    await App.I.agenda.remove(widget.event!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.event == null ? 'Novo compromisso' : 'Editar compromisso'),
          actions: [
            if (widget.event != null) IconButton(tooltip: 'Apagar', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final k in agendaKinds)
              ChoiceChip(
                avatar: Icon(k.icon, size: 18),
                label: Text(k.name),
                selected: _kind == k.name,
                onSelected: (_) => setState(() => _kind = k.name),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Título (opcional)',
              hintText: 'Ex.: $_kind regional',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text('${two(_start.day)}/${two(_start.month)}/${_start.year}'),
                onPressed: _pickDate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(icon: const Icon(Icons.schedule), label: Text(hhmm(_start)), onPressed: _pickTime),
            ),
          ]),
          const SizedBox(height: 12),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: _place.text),
            optionsBuilder: (v) => _places.where((p) => p.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (v) => _place.text = v,
            fieldViewBuilder: (ctx, ctrl, focus, submit) {
              return TextField(
                controller: ctrl,
                focusNode: focus,
                onChanged: (v) => _place.text = v,
                decoration: const InputDecoration(labelText: 'Local (casa de oração)', border: OutlineInputBorder()),
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _repeat,
            decoration: const InputDecoration(labelText: 'Repetição', border: OutlineInputBorder()),
            items: [for (final e in repeatOptions.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _repeat = v ?? 'none'),
          ),
          const SizedBox(height: 16),
          const Text('Avisar antes', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final e in alertOptions.entries)
              FilterChip(
                label: Text(e.value),
                selected: _alerts.contains(e.key),
                onSelected: (s) => setState(() => s ? _alerts.add(e.key) : _alerts.remove(e.key)),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(icon: const Icon(Icons.check), label: const Text('Salvar'), onPressed: _save),
        ]),
      );
}
