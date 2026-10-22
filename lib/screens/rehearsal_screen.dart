import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/rehearsal_repository.dart';
import '../services/app_services.dart';
import '../services/share_builders.dart' show shareFooter;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/share_card.dart';
import 'nav.dart';

const String _groupsKey = 'countGroups';

/// Cartão bonito da contagem para compartilhar.
ShareCardData rehearsalShare(Rehearsal r, List<CountGroup> groups) {
  final t = totalsOf(groups, r.counts);
  return ShareCardData(
    kicker: r.kind,
    title: r.place.isEmpty ? 'Ensaio musical' : r.place,
    subtitle: '${longDate(r.at)} · ${hhmm(r.at)}',
    icon: Icons.groups,
    sections: [
      for (final g in groups)
        if ((t.byGroup[g.name] ?? 0) > 0)
          ShareSection(
            title: g.name,
            total: '${t.byGroup[g.name]}',
            rows: [for (final i in g.items) if ((r.counts[i] ?? 0) > 0) (i, '${r.counts[i]}')],
          ),
      ShareSection(title: 'Resumo', rows: [
        ('Músicos', '${t.musicians}'),
        ('Organistas', '${t.organists}'),
        if (r.notes.isNotEmpty) (r.notes, ''),
      ]),
    ],
    highlight: ('Total geral', '${t.total}'),
    footer: shareFooter,
  );
}

/// Contador do ensaio: instrumentos por naipe, organistas, GEM, encarregados e visitas.
class RehearsalScreen extends StatefulWidget {
  const RehearsalScreen({super.key, this.rehearsal});
  final Rehearsal? rehearsal;
  @override
  State<RehearsalScreen> createState() => _RehearsalScreenState();
}

class _RehearsalScreenState extends State<RehearsalScreen> {
  List<CountGroup> _groups = defaultCountGroups;
  late final Map<String, int> _counts = {...?widget.rehearsal?.counts};
  late DateTime _at = widget.rehearsal?.at ?? DateTime.now();
  late String _kind = widget.rehearsal?.kind ?? rehearsalKinds.first;
  late final _place = TextEditingController(text: widget.rehearsal?.place ?? '');
  late final _notes = TextEditingController(text: widget.rehearsal?.notes ?? '');
  late int? _id = widget.rehearsal?.id;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final raw = p.getString(_groupsKey);
      if (raw != null && mounted) setState(() => _groups = decodeGroups(raw));
    });
    if (widget.rehearsal == null) {
      App.I.places.home().then((h) {
        if (h != null && _place.text.isEmpty && mounted) setState(() => _place.text = h.place.name);
      });
    }
  }

  @override
  void dispose() {
    _place.dispose();
    _notes.dispose();
    super.dispose();
  }

  Rehearsal get _current =>
      Rehearsal(id: _id, at: _at, place: _place.text.trim(), kind: _kind, counts: {..._counts}..removeWhere((_, v) => v == 0), notes: _notes.text.trim());

  void _set(String item, int v) {
    HapticFeedback.selectionClick();
    setState(() {
      _counts[item] = v < 0 ? 0 : v;
      _dirty = true;
    });
  }

  Future<void> _typeCount(String item) async {
    final c = TextEditingController(text: '${_counts[item] ?? 0}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text) ?? 0), child: const Text('OK'))],
      ),
    );
    if (v != null) _set(item, v);
  }

  Future<void> _save() async {
    _id = await App.I.rehearsals.save(_current);
    setState(() => _dirty = false);
    if (mounted) showSnack(context, 'Contagem salva no histórico');
  }

  Future<void> _share() async {
    if (_dirty || _id == null) await _save();
    if (mounted) push(context, ShareCardScreen(data: rehearsalShare(_current, _groups), title: 'Compartilhar contagem'));
  }

  Future<void> _newCount() async {
    if (_dirty) await _save();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => const RehearsalScreen()));
  }

  Future<void> _editGroups() async {
    final g = await push<List<CountGroup>>(context, _GroupsEditor(groups: _groups));
    if (g == null) return;
    (await SharedPreferences.getInstance()).setString(_groupsKey, encodeGroups(g));
    setState(() => _groups = g);
  }

  @override
  Widget build(BuildContext context) {
    final t = totalsOf(_groups, _counts);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contador do ensaio'),
        actions: [
          IconButton(
            tooltip: 'Histórico',
            icon: const Icon(Icons.history),
            onPressed: () => push(context, const RehearsalHistoryScreen()),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'new' => _newCount(),
              'edit' => _editGroups(),
              _ => setState(() {
                  _counts.clear();
                  _dirty = true;
                }),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'new', child: Text('Nova contagem')),
              PopupMenuItem(value: 'zero', child: Text('Zerar tudo')),
              PopupMenuItem(value: 'edit', child: Text('Editar lista de instrumentos')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: AppColors.navy,
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Total geral: ${t.total}',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 20)),
                Text('Músicos ${t.musicians} · Organistas ${t.organists}',
                    style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            IconButton(tooltip: 'Salvar', onPressed: _save, icon: const Icon(Icons.save_outlined, color: Colors.white)),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.navy),
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar'),
              onPressed: _share,
            ),
          ]),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
        TextField(
          controller: _place,
          onChanged: (_) => _dirty = true,
          decoration: const InputDecoration(labelText: 'Igreja (comum)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text('${two(_at.day)}/${two(_at.month)}/${_at.year} ${hhmm(_at)}'),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _at, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d == null || !context.mounted) return;
                final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
                setState(() {
                  _at = DateTime(d.year, d.month, d.day, tm?.hour ?? _at.hour, tm?.minute ?? _at.minute);
                  _dirty = true;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: rehearsalKinds.contains(_kind) ? _kind : rehearsalKinds.first,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: [for (final k in rehearsalKinds) DropdownMenuItem(value: k, child: Text(k))],
              onChanged: (v) => setState(() {
                _kind = v ?? _kind;
                _dirty = true;
              }),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Toque em + e − para contar. Toque no número para digitar.', style: theme.textTheme.bodySmall),
        for (final g in _groups)
          Card(
            margin: const EdgeInsets.only(top: 10),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Chip(label: Text('${t.byGroup[g.name] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
              children: [
                for (final i in g.items)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    child: Row(children: [
                      Expanded(child: Text(i, style: const TextStyle(fontSize: 16))),
                      IconButton(
                        tooltip: 'Menos',
                        onPressed: (_counts[i] ?? 0) > 0 ? () => _set(i, (_counts[i] ?? 0) - 1) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      InkWell(
                        onTap: () => _typeCount(i),
                        child: SizedBox(
                          width: 40,
                          child: Text('${_counts[i] ?? 0}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: (_counts[i] ?? 0) > 0 ? AppColors.navy : theme.disabledColor,
                              )),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mais',
                        onPressed: () => _set(i, (_counts[i] ?? 0) + 1),
                        icon: const Icon(Icons.add_circle, color: AppColors.navy),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          onChanged: (_) => _dirty = true,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder()),
        ),
      ]),
    );
  }
}

/// Contagens salvas.
class RehearsalHistoryScreen extends StatefulWidget {
  const RehearsalHistoryScreen({super.key});
  @override
  State<RehearsalHistoryScreen> createState() => _RehearsalHistoryScreenState();
}

class _RehearsalHistoryScreenState extends State<RehearsalHistoryScreen> {
  List<Rehearsal>? _list;
  List<CountGroup> _groups = defaultCountGroups;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_groupsKey);
    final l = await App.I.rehearsals.all();
    if (!mounted) return;
    setState(() {
      if (raw != null) _groups = decodeGroups(raw);
      _list = l;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = _list;
    return Scaffold(
      appBar: AppBar(title: const Text('Ensaios contados')),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : l.isEmpty
              ? const EmptyState(icon: Icons.history, title: 'Nenhuma contagem salva')
              : ListView(padding: const EdgeInsets.all(12), children: [
                  for (final r in l)
                    Card(
                      child: ListTile(
                        title: Text(r.place.isEmpty ? r.kind : '${r.place} · ${r.kind}'),
                        subtitle: Text('${two(r.at.day)}/${two(r.at.month)}/${r.at.year} · '
                            'total ${totalsOf(_groups, r.counts).total}'),
                        onTap: () async {
                          await push(context, RehearsalScreen(rehearsal: r));
                          _load();
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'share') {
                              push(context, ShareCardScreen(data: rehearsalShare(r, _groups)));
                            } else {
                              await App.I.rehearsals.remove(r.id!);
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
}

/// Editar grupos e itens da contagem (incluir instrumento, renomear, remover).
class _GroupsEditor extends StatefulWidget {
  const _GroupsEditor({required this.groups});
  final List<CountGroup> groups;
  @override
  State<_GroupsEditor> createState() => _GroupsEditorState();
}

class _GroupsEditorState extends State<_GroupsEditor> {
  late final List<CountGroup> _g = [...widget.groups];

  Future<String?> _ask(String title, [String initial = '']) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  void _replace(int gi, List<String> items) =>
      setState(() => _g[gi] = CountGroup(_g[gi].name, items, musicians: _g[gi].musicians));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Lista de instrumentos'),
          actions: [
            TextButton(
              onPressed: () => setState(() {
                _g
                  ..clear()
                  ..addAll(defaultCountGroups);
              }),
              child: const Text('Padrão'),
            ),
            TextButton(onPressed: () => Navigator.pop(context, _g), child: const Text('Salvar')),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Grupo'),
          onPressed: () async {
            final n = await _ask('Novo grupo');
            if (n != null && n.isNotEmpty) setState(() => _g.add(CountGroup(n, const [])));
          },
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
          for (var gi = 0; gi < _g.length; gi++)
            Card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ListTile(
                  title: Text(_g[gi].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_g[gi].musicians ? 'Conta como músicos' : 'Não conta como músicos'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(
                      value: _g[gi].musicians,
                      onChanged: (v) => setState(() => _g[gi] = CountGroup(_g[gi].name, _g[gi].items, musicians: v)),
                    ),
                    IconButton(
                      tooltip: 'Remover grupo',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _g.removeAt(gi)),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final i in _g[gi].items)
                      InputChip(
                        label: Text(i),
                        onPressed: () async {
                          final n = await _ask('Renomear', i);
                          if (n != null && n.isNotEmpty) _replace(gi, [for (final x in _g[gi].items) x == i ? n : x]);
                        },
                        onDeleted: () => _replace(gi, [..._g[gi].items]..remove(i)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Item'),
                      onPressed: () async {
                        final n = await _ask('Novo item em ${_g[gi].name}');
                        if (n != null && n.isNotEmpty) _replace(gi, [..._g[gi].items, n]);
                      },
                    ),
                  ]),
                ),
              ]),
            ),
        ]),
      );
}
