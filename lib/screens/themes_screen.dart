import 'package:flutter/material.dart';

import '../data/content.dart';
import '../services/app_services.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Índice temático com referências que abrem o capítulo destacando o versículo.
class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final themes = App.I.themes;
    return Scaffold(
      appBar: AppBar(title: const Text('Temas bíblicos')),
      body: ListView.builder(
        itemCount: themes.length,
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.local_offer_outlined, color: AppColors.gold),
          title: Text(themes[i].name),
          subtitle: Text('${themes[i].refs.length} referências · ${themes[i].description}'),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => ThemeDetailScreen(theme: themes[i]))),
        ),
      ),
    );
  }
}

class ThemeDetailScreen extends StatelessWidget {
  const ThemeDetailScreen({super.key, required this.theme});
  final BibleThemeData theme;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(theme.name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(theme.description, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        const SourceTag(biblical: true),
        for (final r in theme.refs) ...[PassageView(r), const Divider()],
      ]),
    );
  }
}
