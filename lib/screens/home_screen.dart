import 'package:flutter/material.dart';

import '../data/bible_books.dart';
import '../data/hymn_repository.dart';
import '../services/app_services.dart';
import '../services/documents.dart';
import '../theme.dart';
import 'documents_screen.dart';
import 'nav.dart';
import 'plan_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'shell.dart';
import 'study_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = App.I;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bíblia & Hinos CCB'),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => push(context, const SettingsScreen()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.settings, app.documents, app.bibleVersion]),
        builder: (context, _) {
          final last = app.settings.lastChapter;
          final lastHymn = app.settings.lastHymn;
          final noDocs = !app.documents.has(DocKind.bible) &&
              !app.documents.has(DocKind.hymnalDo) &&
              !app.documents.has(DocKind.hymnalOrgao) &&
              !app.hasBibleText;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SearchBox(onTap: () => push(context, const SearchScreen())),
              if (noDocs) ...[
                const SizedBox(height: 12),
                Card(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  child: ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: const Text('Importe seus documentos'),
                    subtitle: const Text(
                        'Selecione no celular os PDFs da Bíblia e do Hinário 5 para usar o app offline.'),
                    onTap: () => push(context, const DocumentsScreen()),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (last != null || lastHymn != null)
                Row(children: [
                  if (last != null)
                    Expanded(
                      child: _MiniCard(
                        icon: Icons.history_edu,
                        label: 'Continuar leitura',
                        value: '${bookById(last.$1).name} ${last.$2}',
                        onTap: () => app.hasBibleText
                            ? openChapter(context, last.$1, last.$2)
                            : openBiblePdf(context, book: last.$1, chapter: last.$2),
                      ),
                    ),
                  if (last != null && lastHymn != null) const SizedBox(width: 10),
                  if (lastHymn != null)
                    Expanded(
                      child: _MiniCard(
                        icon: Icons.music_note,
                        label: 'Último hino',
                        value: Hymn.labelFor(lastHymn),
                        onTap: () => openHymn(context, lastHymn),
                      ),
                    ),
                ]),
              const SizedBox(height: 4),
              _HomeCard(
                icon: Icons.menu_book,
                title: 'Bíblia Sagrada',
                subtitle: app.hasBibleText
                    ? 'Almeida Revista e Corrigida · ${app.verseCount} versículos indexados'
                    : app.documents.has(DocKind.bible)
                        ? 'PDF importado · leitura pelo PDF'
                        : 'Importe o PDF para começar',
                onTap: () => Shell.goTo(context, 1),
              ),
              _HomeCard(
                icon: Icons.library_music,
                title: 'Hinário 5',
                subtitle: '480 hinos e 6 coros',
                onTap: () => Shell.goTo(context, 2),
              ),
              _HomeCard(
                icon: Icons.wb_sunny_outlined,
                title: 'Estudo do Dia',
                subtitle: StudyScreen.todayStudy().title,
                onTap: () => push(context, const StudyScreen()),
              ),
              _HomeCard(
                icon: Icons.quiz,
                title: 'Quiz Bíblico',
                subtitle: '${app.questions.length} perguntas em 3 níveis',
                onTap: () => Shell.goTo(context, 3),
              ),
              _HomeCard(
                icon: Icons.event_note,
                title: 'Plano de Leitura',
                subtitle: 'A Bíblia inteira em 365 dias',
                onTap: () => push(context, const PlanScreen()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(children: [
            const Icon(Icons.search),
            const SizedBox(width: 12),
            Expanded(
              child: Text('João 3:16, perdão, hino 120…',
                  style: t.textTheme.bodyLarge?.copyWith(color: t.hintColor)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.gold,
            child: Icon(icon),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(icon, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
        ),
      );
}
