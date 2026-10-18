import 'package:flutter/material.dart';

import '../data/hymn_repository.dart';
import '../services/app_services.dart';
import '../services/documents.dart';
import '../theme.dart';
import 'documents_screen.dart';
import 'hymn_mapping_screen.dart';
import 'nav.dart';

/// Índice do Hinário 5: 480 hinos + 6 coros, busca, favoritos e histórico.
class HymnalScreen extends StatefulWidget {
  const HymnalScreen({super.key});
  @override
  State<HymnalScreen> createState() => _HymnalScreenState();
}

class _HymnalScreenState extends State<HymnalScreen> {
  List<Hymn> _all = [];
  List<Hymn> _shown = [];
  Set<String> _favs = {};
  bool _onlyFavs = false;
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await App.I.hymns.all();
    final favs = await App.I.user.favoriteKeys('hymn');
    if (!mounted) return;
    _all = all;
    _favs = favs;
    await _apply();
  }

  Future<void> _apply() async {
    var list = _query.isEmpty ? _all : await App.I.hymns.search(_query);
    if (_onlyFavs) list = list.where((h) => _favs.contains('${h.number}')).toList();
    if (mounted) setState(() => _shown = list);
  }

  Future<void> _open(int n) async {
    await openHymn(context, n);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = App.I;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hinário 5'),
        actions: [
          IconButton(
            tooltip: 'Histórico',
            icon: const Icon(Icons.history),
            onPressed: () async {
              final h = await app.user.history('hymn', limit: 30);
              if (!context.mounted) return;
              await showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => h.isEmpty
                    ? const SizedBox(height: 120, child: Center(child: Text('Nenhum hino acessado ainda.')))
                    : ListView(children: [
                        for (final e in h)
                          ListTile(
                            leading: const Icon(Icons.music_note),
                            title: Text(e.label),
                            onTap: () {
                              Navigator.pop(ctx);
                              _open(int.parse(e.refKey));
                            },
                          ),
                      ]),
              );
            },
          ),
          IconButton(
            tooltip: 'Mapeamento de páginas',
            icon: const Icon(Icons.tune),
            onPressed: () => push(context, const HymnMappingScreen()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.settings, app.documents]),
        builder: (context, _) {
          final doc = app.settings.hymnDoc;
          final hasDoc = app.documents.has(DocKind.hymnal(doc));
          final choirs = _shown.where((h) => h.isChoir).toList();
          final hymns = _shown.where((h) => !h.isChoir).toList();
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'do', label: Text('Em Dó')),
                      ButtonSegment(value: 'orgao', label: Text('Órgão')),
                    ],
                    selected: {doc},
                    onSelectionChanged: (s) => app.settings.hymnDoc = s.first,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Número ou título (ex.: 120, coro 3)',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      suffixIcon: IconButton(
                        tooltip: 'Somente favoritos',
                        icon: Icon(_onlyFavs ? Icons.star : Icons.star_border, color: AppColors.gold),
                        onPressed: () {
                          _onlyFavs = !_onlyFavs;
                          _apply();
                        },
                      ),
                    ),
                    onChanged: (v) {
                      _query = v.trim();
                      _apply();
                    },
                    onSubmitted: (v) {
                      final n = int.tryParse(v.trim());
                      if (n != null && n >= 1 && n <= Hymns.hymnCount) _open(n);
                    },
                  ),
                  if (!hasDoc)
                    Card(
                      margin: const EdgeInsets.only(top: 10),
                      color: AppColors.gold.withValues(alpha: 0.15),
                      child: ListTile(
                        leading: const Icon(Icons.file_upload_outlined),
                        title: Text('${Hymns.docLabel(doc)} não importado'),
                        subtitle: const Text('Importe o PDF para ver as partituras.'),
                        onTap: () => push(context, const DocumentsScreen()),
                      ),
                    ),
                ]),
              ),
            ),
            if (_shown.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Nenhum hino encontrado. Títulos só podem ser pesquisados quando '
                      'cadastrados (abra o hino › menu › Editar título).', textAlign: TextAlign.center),
                ),
              ),
            if (hymns.isNotEmpty) _grid(hymns),
            if (choirs.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('COROS', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                ),
              ),
              _grid(choirs),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]);
        },
      ),
    );
  }

  Widget _grid(List<Hymn> list) {
    final withTitles = list.any((h) => h.title != null);
    if (withTitles && _query.isNotEmpty) {
      return SliverList.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.music_note, color: AppColors.gold),
          title: Text(list[i].display),
          onTap: () => _open(list[i].number),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 64, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final h = list[i];
          final fav = _favs.contains('${h.number}');
          return OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: fav ? AppColors.gold.withValues(alpha: 0.2) : null,
              side: const BorderSide(color: AppColors.gold),
            ),
            onPressed: () => _open(h.number),
            child: Text(h.isChoir ? 'C${h.number - Hymns.hymnCount}' : '${h.number}'),
          );
        },
      ),
    );
  }
}
