import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/user_repository.dart';
import '../services/app_services.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'nav.dart';
import 'study_screen.dart';

/// Favoritos, marcações/anotações e histórico.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Favorite> _favs = [];
  List<(Bookmark, Verse?)> _marks = [];
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = App.I;
    final favs = await app.user.favorites();
    final marks = await app.user.allBookmarks();
    final withVerses = <(Bookmark, Verse?)>[
      for (final m in marks) (m, await app.bible.verseById(m.verseId)),
    ];
    final history = [...await app.user.history('chapter'), ...await app.user.history('hymn')]
      ..sort((a, b) => b.at.compareTo(a.at));
    if (mounted) {
      setState(() {
        _favs = favs;
        _marks = withVerses;
        _history = history;
      });
    }
  }

  Future<void> _openFav(Favorite f) async {
    switch (f.kind) {
      case 'verse':
        final id = int.parse(f.refKey);
        await openChapter(context, id ~/ 1000000, (id ~/ 1000) % 1000, verse: id % 1000);
      case 'hymn':
        await openHymn(context, int.parse(f.refKey));
      case 'study':
        await push(context, StudyScreen(studyId: int.parse(f.refKey)));
    }
    _load();
  }

  Widget _favList(String kind, IconData icon) {
    final list = _favs.where((f) => f.kind == kind).toList();
    if (list.isEmpty) {
      return const EmptyState(icon: Icons.star_border, title: 'Nenhum favorito ainda');
    }
    return ListView(children: [
      for (final f in list)
        Dismissible(
          key: ValueKey('${f.kind}${f.refKey}'),
          background: Container(color: Colors.red.withValues(alpha: 0.3)),
          onDismissed: (_) async {
            await App.I.user.toggleFavorite(f.kind, f.refKey, f.label);
            _load();
          },
          child: ListTile(
            leading: Icon(icon, color: AppColors.gold),
            title: Text(f.label),
            subtitle: kind == 'verse'
                ? FutureBuilder<Verse?>(
                    future: App.I.bible.verseById(int.parse(f.refKey)),
                    builder: (_, s) => Text(s.data?.text ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  )
                : null,
            onTap: () => _openFav(f),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favoritos'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.gold,
            tabs: [
              Tab(text: 'Versículos'),
              Tab(text: 'Hinos'),
              Tab(text: 'Estudos'),
              Tab(text: 'Marcações'),
              Tab(text: 'Histórico'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _favList('verse', Icons.format_quote),
          _favList('hymn', Icons.music_note),
          _favList('study', Icons.wb_sunny_outlined),
          _marks.isEmpty
              ? const EmptyState(
                  icon: Icons.border_color_outlined,
                  title: 'Nenhuma marcação ou anotação',
                  message: 'No leitor, toque nos versículos para marcar ou anotar.')
              : ListView(children: [
                  for (final (m, v) in _marks)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 10,
                        backgroundColor: m.color == null
                            ? Colors.transparent
                            : AppColors.highlights[m.color! % AppColors.highlights.length],
                        child: m.note != null ? const Icon(Icons.sticky_note_2_outlined, size: 14) : null,
                      ),
                      title: Text(v?.ref.label ?? 'Versículo ${m.verseId}'),
                      subtitle: Text(m.note ?? v?.text ?? '', maxLines: 3, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        final id = m.verseId;
                        await openChapter(context, id ~/ 1000000, (id ~/ 1000) % 1000, verse: id % 1000);
                        _load();
                      },
                    ),
                ]),
          _history.isEmpty
              ? const EmptyState(icon: Icons.history, title: 'Histórico vazio')
              : ListView(children: [
                  for (final h in _history)
                    ListTile(
                      leading: Icon(h.kind == 'hymn' ? Icons.music_note : Icons.menu_book, color: AppColors.gold),
                      title: Text(h.label),
                      subtitle: Text('${h.at.day.toString().padLeft(2, '0')}/${h.at.month.toString().padLeft(2, '0')} '
                          '${h.at.hour.toString().padLeft(2, '0')}:${h.at.minute.toString().padLeft(2, '0')}'),
                      onTap: () async {
                        if (h.kind == 'hymn') {
                          await openHymn(context, int.parse(h.refKey));
                        } else {
                          final p = h.refKey.split(':');
                          await openChapter(context, int.parse(p[0]), int.parse(p[1]));
                        }
                        _load();
                      },
                    ),
                ]),
        ]),
      ),
    );
  }
}
