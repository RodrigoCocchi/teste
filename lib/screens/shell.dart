import 'package:flutter/material.dart';

import 'bible_index_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'hymnal_screen.dart';
import 'quiz_screen.dart';

/// Navegação inferior: Início | Bíblia | Hinário | Quiz | Favoritos.
class Shell extends StatefulWidget {
  const Shell({super.key});

  static void goTo(BuildContext context, int tab) =>
      context.findAncestorStateOfType<_ShellState>()?.select(tab);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final _visited = <int>{0};

  void select(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomeScreen(),
      BibleIndexScreen(),
      HymnalScreen(),
      QuizScreen(),
      FavoritesScreen(),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) select(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < pages.length; i++)
              _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: select,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Bíblia'),
            NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Hinário'),
            NavigationDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz), label: 'Quiz'),
            NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Favoritos'),
          ],
        ),
      ),
    );
  }
}
