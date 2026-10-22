import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../services/app_services.dart';
import '../services/app_reminders.dart';
import '../services/backup.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import 'documents_screen.dart';
import 'hymn_mapping_screen.dart';
import 'nav.dart';
import 'profile_screen.dart';
import 'voice_settings_screen.dart';

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
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('Meu perfil'),
            subtitle: const Text('Nome, comum e batismo (lembrete do aniversário de batismo)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(context, const ProfileScreen()),
          ),
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
          const SectionTitle('Leitura em áudio'),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Voz do leitor'),
            subtitle: const Text('Escolher voz, tom e velocidade da Bíblia em áudio'),
            onTap: () => push(context, const VoiceSettingsScreen()),
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
          const SectionTitle('Backup'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Fazer backup'),
            subtitle: const Text('Favoritos, marcações, anotações, casas de oração, lista de oração e plano de leitura'),
            onTap: () => _backup(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: const Text('Restaurar backup'),
            subtitle: const Text('Junta os dados do arquivo aos que já estão no celular'),
            onTap: () => _restore(context),
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

  Future<void> _backup(BuildContext context) async {
    try {
      final now = DateTime.now();
      final name = 'backup_biblia_hinos_${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}.json';
      final f = File(p.join((await getTemporaryDirectory()).path, name));
      await f.writeAsString(encodeBackup(await buildBackup(App.I.db.db, prefs: await SharedPreferences.getInstance())));
      await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'application/json')],
        text: 'Backup do Bíblia & Hinos. Guarde este arquivo (Drive, WhatsApp, e-mail) para restaurar depois.',
      ));
    } on Object {
      if (context.mounted) showSnack(context, 'Não foi possível gerar o backup.');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    final path = files.isEmpty ? null : files.first.path;
    if (path == null) return;
    try {
      final n = await restoreBackup(App.I.db.db, await File(path).readAsString(), prefs: await SharedPreferences.getInstance());
      await refreshReminders();
      App.I.settings.touch();
      if (context.mounted) showSnack(context, 'Backup restaurado: $n itens.');
    } on FormatException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    } on Object {
      if (context.mounted) showSnack(context, 'Não foi possível ler o arquivo.');
    }
  }
}
