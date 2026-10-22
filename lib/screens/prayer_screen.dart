import 'package:flutter/material.dart';

import '../data/prayer_repository.dart';
import '../services/app_services.dart';
import '../theme.dart';
import '../widgets/common.dart';

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Lista de oração pessoal: pedidos e o registro de quando foram atendidos.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});
  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  List<PrayerItem> _open = [], _answered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = App.I.prayers;
    final o = await repo.list(answered: false);
    final a = await repo.list(answered: true);
    if (mounted) {
      setState(() {
        _open = o;
        _answered = a;
        _loading = false;
      });
    }
  }

  Future<String?> _textDialog(String title, {String initial = '', String hint = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Salvar')),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final t = await _textDialog('Novo pedido de oração', hint: 'Ex.: pela saúde da irmã Maria');
    if (t == null || t.trim().isEmpty) return;
    await App.I.prayers.add(t);
    _load();
  }

  Future<void> _edit(PrayerItem p) async {
    final t = await _textDialog('Editar pedido', initial: p.text);
    if (t == null || t.trim().isEmpty) return;
    await App.I.prayers.edit(p.id, t);
    _load();
  }

  Future<void> _answer(PrayerItem p) async {
    final note = await _textDialog('Graças a Deus! Pedido atendido',
        hint: 'Se quiser, anote como foi atendido (opcional)');
    if (note == null) return;
    await App.I.prayers.setAnswered(p.id, true, note: note);
    _load();
    if (mounted) showSnack(context, 'Movido para "Atendidos"');
  }

  Future<void> _remove(PrayerItem p) async {
    await App.I.prayers.remove(p.id);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Pedido apagado'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            final id = await App.I.prayers.add(p.text);
            if (p.answered) await App.I.prayers.setAnswered(id, true, note: p.note);
            _load();
          },
        ),
      ));
    }
  }

  Widget _tile(PrayerItem p) => Card(
        child: ListTile(
          leading: Icon(p.answered ? Icons.check_circle : Icons.volunteer_activism_outlined,
              color: p.answered ? Colors.green : AppColors.navy),
          title: Text(p.text),
          subtitle: Text([
            'Desde ${_date(p.createdAt)}',
            if (p.answered) 'Atendido em ${_date(p.answeredAt!)}',
            if (p.note != null) p.note!,
          ].join('\n')),
          isThreeLine: p.answered,
          onTap: p.answered ? null : () => _edit(p),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'answer':
                  _answer(p);
                case 'reopen':
                  App.I.prayers.setAnswered(p.id, false).then((_) => _load());
                case 'edit':
                  _edit(p);
                case 'remove':
                  _remove(p);
              }
            },
            itemBuilder: (_) => [
              if (!p.answered) const PopupMenuItem(value: 'answer', child: Text('Marcar como atendido')),
              if (p.answered) const PopupMenuItem(value: 'reopen', child: Text('Voltar para "Em oração"')),
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              const PopupMenuItem(value: 'remove', child: Text('Apagar')),
            ],
          ),
        ),
      );

  Widget _list(List<PrayerItem> items, String empty) => items.isEmpty
      ? EmptyState(icon: Icons.volunteer_activism_outlined, title: empty)
      : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [for (final p in items) _tile(p)]);

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Lista de oração'),
            bottom: TabBar(tabs: [
              Tab(text: 'Em oração (${_open.length})'),
              Tab(text: 'Atendidos (${_answered.length})'),
            ]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Novo pedido'),
            onPressed: _add,
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [
                  _list(_open, 'Nenhum pedido. Toque em "Novo pedido" para anotar.'),
                  _list(_answered, 'Os pedidos atendidos aparecem aqui.'),
                ]),
        ),
      );
}
