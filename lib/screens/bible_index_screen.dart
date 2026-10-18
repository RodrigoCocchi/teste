import 'package:flutter/material.dart';

import '../core/text_utils.dart';
import '../data/bible_books.dart';
import '../services/app_services.dart';
import '../services/documents.dart';
import '../theme.dart';
import 'documents_screen.dart';
import 'nav.dart';
import 'plan_screen.dart';
import 'themes_screen.dart';

/// Índice dos 66 livros (39 AT + 27 NT) com filtro por nome/abreviação.
class BibleIndexScreen extends StatefulWidget {
  const BibleIndexScreen({super.key});
  @override
  State<BibleIndexScreen> createState() => _BibleIndexScreenState();
}

class _BibleIndexScreenState extends State<BibleIndexScreen> {
  String _filter = '';
  Map<int, int> _available = {};

  @override
  void initState() {
    super.initState();
    App.I.bibleVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    App.I.bibleVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final m = await App.I.bible.chapterCountsByBook();
    if (mounted) setState(() => _available = m);
  }

  bool _matches(BibleBook b) {
    if (_filter.isEmpty) return true;
    final f = normalize(_filter).replaceAll(' ', '');
    return normalize(b.name).replaceAll(' ', '').contains(f) ||
        normalize(b.abbrev).startsWith(f) ||
        b.aliases.any((a) => a.startsWith(f));
  }

  @override
  Widget build(BuildContext context) {
    final app = App.I;
    final books = bibleBooks.where(_matches).toList();
    final ot = books.where((b) => b.isOldTestament).toList();
    final nt = books.where((b) => !b.isOldTestament).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bíblia Sagrada'),
        actions: [
          IconButton(
            tooltip: 'Temas bíblicos',
            icon: const Icon(Icons.local_offer_outlined),
            onPressed: () => push(context, const ThemesScreen()),
          ),
          IconButton(
            tooltip: 'Plano de leitura',
            icon: const Icon(Icons.event_note),
            onPressed: () => push(context, const PlanScreen()),
          ),
          IconButton(
            tooltip: 'Abrir PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => openBiblePdf(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: app.documents,
        builder: (context, _) => CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Livro ou abreviação (ex.: Jo, Salmos)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v.trim()),
              ),
            ),
          ),
          if (!app.hasBibleText)
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                color: AppColors.gold.withValues(alpha: 0.15),
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(app.documents.has(DocKind.bible)
                      ? 'Leitura pelo PDF'
                      : 'Bíblia ainda não importada'),
                  subtitle: Text(app.documents.has(DocKind.bible)
                      ? 'O texto ainda não foi indexado. Busca por palavras, cópia de versículos, '
                          'marcações e notas dependem da indexação.'
                      : 'Importe o PDF da Bíblia em Documentos.'),
                  onTap: () => push(context, const DocumentsScreen()),
                ),
              ),
            ),
          _header('Antigo Testamento', ot.length, 39),
          _grid(ot),
          _header('Novo Testamento', nt.length, 27),
          _grid(nt),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      ),
    );
  }

  Widget _header(String title, int shown, int total) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text('$title · $shown de $total livros',
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        ),
      );

  Widget _grid(List<BibleBook> books) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverList.builder(
          itemCount: books.length,
          itemBuilder: (context, i) {
            final b = books[i];
            final avail = _available[b.id] ?? 0;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.navy,
                foregroundColor: AppColors.gold,
                child: Text(b.abbrev, style: const TextStyle(fontSize: 12)),
              ),
              title: Text(b.name, style: const TextStyle(fontSize: 16)),
              subtitle: Text(App.I.hasBibleText
                  ? '${b.chapters} capítulos${avail < b.chapters ? ' · $avail indexados' : ''}'
                  : '${b.chapters} capítulos'),
              onTap: () => push(context, ChapterPickerScreen(book: b)),
            );
          },
        ),
      );
}

/// Livro → Capítulo → Versículo.
class ChapterPickerScreen extends StatelessWidget {
  const ChapterPickerScreen({super.key, required this.book});
  final BibleBook book;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(book.name)),
      body: FutureBuilder<Set<int>>(
        future: App.I.bible.availableChapters(book.id),
        builder: (context, snap) {
          final avail = snap.data ?? {};
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 64, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: book.chapters,
            itemBuilder: (context, i) {
              final c = i + 1;
              final has = avail.contains(c);
              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: has ? AppColors.gold : Colors.grey.withValues(alpha: 0.4)),
                ),
                onPressed: () => has
                    ? _pickVerse(context, c)
                    : openBiblePdf(context, book: book.id, chapter: c),
                child: Text('$c', style: const TextStyle(fontSize: 16)),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickVerse(BuildContext context, int chapter) async {
    final info = await App.I.bible.chapterInfo(book.id, chapter);
    if (!context.mounted || info == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${book.name} $chapter', style: Theme.of(ctx).textTheme.titleLarge),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                label: const Text('Ler o capítulo'),
                onPressed: () {
                  Navigator.pop(ctx);
                  openChapter(context, book.id, chapter);
                },
              ),
            ),
            const Text('ou escolha o versículo'),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 56, mainAxisSpacing: 6, crossAxisSpacing: 6),
                itemCount: info.verseCount,
                itemBuilder: (_, i) => TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openChapter(context, book.id, chapter, verse: i + 1);
                  },
                  child: Text('${i + 1}'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
