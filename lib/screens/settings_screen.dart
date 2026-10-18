import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import 'documents_screen.dart';
import 'hymn_mapping_screen.dart';
import 'nav.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = App.I.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(children: [
          const SectionTitle('Aparência'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ReadingTheme>(
              segments: const [
                ButtonSegment(value: ReadingTheme.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ReadingTheme.sepia, label: Text('Sépia'), icon: Icon(Icons.auto_stories)),
                ButtonSegment(value: ReadingTheme.dark, label: Text('Escuro'), icon: Icon(Icons.dark_mode)),
              ],
              selected: {s.theme},
              onSelectionChanged: (v) => s.theme = v.first,
            ),
          ),
          ListTile(
            title: Text('Fonte do leitor: ${s.fontSize.round()}'),
            subtitle: Slider(min: 13, max: 34, divisions: 21, value: s.fontSize, onChanged: (v) => s.fontSize = v),
          ),
          const SectionTitle('Documentos'),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Importar e indexar documentos'),
            subtitle: const Text('Bíblia (PDF/JSON) e Hinário 5 (Dó e órgão)'),
            onTap: () => push(context, const DocumentsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Páginas dos hinos'),
            onTap: () => push(context, const HymnMappingScreen()),
          ),
          const SectionTitle('Dados'),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Limpar histórico de leitura'),
            onTap: () async {
              await App.I.user.clearHistory('chapter');
              await App.I.user.clearHistory('hymn');
              if (context.mounted) showSnack(context, 'Histórico apagado');
            },
          ),
          const SectionTitle('Sobre'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              'Bíblia & Hinos CCB — uso pessoal, 100% offline.\n\n'
              'Os textos bíblicos exibidos vêm exclusivamente do documento importado por você. '
              'Estudos, reflexões e perguntas são textos autorais deste aplicativo e não '
              'representam ensinamentos oficiais da Congregação Cristã no Brasil.\n\n'
              'Perguntas do quiz são marcadas como "conferidas" somente depois de comparadas '
              'com o texto bíblico importado.',
            ),
          ),
        ]),
      ),
    );
  }
}
