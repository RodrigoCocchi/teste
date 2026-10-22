import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/places_repository.dart';
import '../services/app_services.dart';
import '../services/ccb_relatorio.dart';
import '../services/app_reminders.dart';
import '../services/reminders.dart';
import '../services/share_builders.dart';
import '../widgets/share_card.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/directions.dart';
import 'nav.dart';
import 'relatorio_screen.dart';

/// Texto curto do próximo culto: "Quinta 19:30 · Culto Oficial".
String nextCultoLabel(SavedPlace p, DateTime now) {
  final n = nextCulto(p.cultos, now);
  if (n == null) return 'Sem horários salvos';
  final (c, at) = n;
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(at.year, at.month, at.day).difference(today).inDays;
  final day = diff == 0 ? 'Hoje' : diff == 1 ? 'Amanhã' : c.dayName;
  return '$day ${c.time} · ${c.kind}';
}

/// Casas de oração salvas no aparelho: horários sem internet, lembretes e rota.
class MyPlacesScreen extends StatefulWidget {
  const MyPlacesScreen({super.key});
  @override
  State<MyPlacesScreen> createState() => _MyPlacesScreenState();
}

class _MyPlacesScreenState extends State<MyPlacesScreen> {
  List<SavedPlace>? _places;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await App.I.places.all();
    if (mounted) setState(() => _places = p);
  }

  Future<void> _setRemind(SavedPlace p, int? minutes) async {
    if (minutes != null && !await CultoReminders.instance.requestPermission()) {
      if (mounted) showSnack(context, 'Permita as notificações do app para receber os lembretes.');
      return;
    }
    await App.I.places.setRemind(p.place.id, minutes);
    await refreshReminders();
    await _load();
    if (mounted) {
      showSnack(context, minutes == null ? 'Lembretes desligados' : 'Lembrete ${remindOptions[minutes]} de cada culto');
    }
  }

  Future<void> _refreshFromSite(SavedPlace p) async {
    final api = CcbRelatorio();
    try {
      final d = await api.detalhe(p.place.id);
      if (d.isEmpty) throw StateError('vazio');
      await App.I.places.save(p.place, d);
      await refreshReminders();
      await _load();
      if (mounted) showSnack(context, 'Horários atualizados');
    } on Object {
      if (mounted) showSnack(context, 'Sem conexão com o site da CCB. Os horários salvos continuam valendo.');
    } finally {
      api.close();
    }
  }

  Future<void> _remove(SavedPlace p) async {
    await App.I.places.remove(p.place.id);
    await refreshReminders();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final places = _places;
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas casas de oração')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.search),
        label: const Text('Procurar'),
        onPressed: () async {
          await push(context, const RelatorioScreen());
          _load();
        },
      ),
      body: places == null
          ? const Center(child: CircularProgressIndicator())
          : places.isEmpty
              ? const EmptyState(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Nenhuma casa de oração salva',
                  message: 'Procure uma casa de oração, abra os detalhes e toque em "Salvar" ou "Minha comum". '
                      'Os horários ficam no celular e funcionam sem internet.',
                )
              : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
                  for (final p in places) _card(p),
                ]),
    );
  }

  Widget _card(SavedPlace p) {
    final t = Theme.of(context);
    final cultos = p.cultos;
    final kinds = <String, List<CultoTime>>{};
    for (final c in cultos) {
      kinds.putIfAbsent(c.kind, () => []).add(c);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(p.isHome ? Icons.home : Icons.place_outlined, color: AppColors.navy),
            const SizedBox(width: 8),
            Expanded(child: Text(p.place.name, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'home':
                    await App.I.places.setHome(p.place.id, !p.isHome);
                    await _load();
                  case 'refresh':
                    await _refreshFromSite(p);
                  case 'remove':
                    await _remove(p);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'home', child: Text(p.isHome ? 'Deixar de ser minha comum' : 'Definir como minha comum')),
                const PopupMenuItem(value: 'refresh', child: Text('Atualizar horários do site')),
                const PopupMenuItem(value: 'remove', child: Text('Remover')),
              ],
            ),
          ]),
          if (p.isHome) Text('Minha comum', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          Text(p.address, style: t.textTheme.bodySmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
            child: Text('Próximo: ${nextCultoLabel(p, DateTime.now())}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 6),
          for (final e in kinds.entries) ...[
            Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
            Text(e.value.map((c) => '${c.dayName} ${c.time}').join(' · ')),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.directions),
              label: const Text('Como chegar'),
              onPressed: () => showDirectionsChooser(context, p.address),
            ),
            if (nextCulto(p.cultos, DateTime.now()) case (final c, final at))
              OutlinedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Compartilhar culto'),
                onPressed: () => push(context, ShareCardScreen(data: cultoShare(p, c, at))),
              ),
            PopupMenuButton<int>(
              tooltip: 'Lembrete',
              onSelected: (m) => _setRemind(p, m < 0 ? null : m),
              itemBuilder: (_) => [
                for (final e in remindOptions.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
                const PopupMenuItem(value: -1, child: Text('Sem lembrete')),
              ],
              child: Chip(
                avatar: Icon(p.remindMinutes == null ? Icons.notifications_none : Icons.notifications_active,
                    size: 18, color: p.remindMinutes == null ? null : AppColors.gold),
                label: Text(p.remindMinutes == null ? 'Lembrete' : remindOptions[p.remindMinutes] ?? 'Lembrete'),
              ),
            ),
            for (final phone in p.phones)
              ActionChip(
                avatar: const Icon(Icons.call, size: 18),
                label: Text(phone),
                onPressed: () => launchUrl(Uri.parse('tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}')),
              ),
          ]),
          Text('Horários salvos em ${p.updatedAt.day.toString().padLeft(2, '0')}/${p.updatedAt.month.toString().padLeft(2, '0')}',
              style: t.textTheme.labelSmall),
        ]),
      ),
    );
  }
}

/// Botões "Salvar" e "Minha comum" no detalhe de uma casa de oração.
class SavePlaceButtons extends StatefulWidget {
  const SavePlaceButtons({super.key, required this.place, required this.sections});
  final RelPlace place;
  final List<RelSection> sections;
  @override
  State<SavePlaceButtons> createState() => _SavePlaceButtonsState();
}

class _SavePlaceButtonsState extends State<SavePlaceButtons> {
  SavedPlace? _saved;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    App.I.places.get(widget.place.id).then((s) {
      if (mounted) {
        setState(() {
          _saved = s;
          _loaded = true;
        });
      }
    });
  }

  Future<void> _toggleSaved() async {
    final repo = App.I.places;
    if (_saved != null) {
      await repo.remove(widget.place.id);
    } else {
      await repo.save(widget.place, widget.sections);
    }
    await refreshReminders();
    final s = await repo.get(widget.place.id);
    if (mounted) setState(() => _saved = s);
  }

  Future<void> _toggleHome() async {
    final repo = App.I.places;
    await repo.save(widget.place, widget.sections);
    await repo.setHome(widget.place.id, !(_saved?.isHome ?? false));
    await refreshReminders();
    final s = await repo.get(widget.place.id);
    if (mounted) {
      setState(() => _saved = s);
      if (s?.isHome ?? false) showSnack(context, 'Definida como minha comum. Veja na tela inicial.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || widget.sections.isEmpty) return const SizedBox.shrink();
    final saved = _saved != null;
    final home = _saved?.isHome ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 8, children: [
        OutlinedButton.icon(
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? AppColors.gold : null),
          label: Text(saved ? 'Salva' : 'Salvar'),
          onPressed: _toggleSaved,
        ),
        OutlinedButton.icon(
          icon: Icon(home ? Icons.home : Icons.home_outlined, color: home ? AppColors.gold : null),
          label: Text(home ? 'Minha comum' : 'Definir como minha comum'),
          onPressed: _toggleHome,
        ),
      ]),
    );
  }
}
