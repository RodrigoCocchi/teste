import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bible_books.dart';
import '../services/app_services.dart';
import '../services/documents.dart';
import '../widgets/common.dart';
import '../widgets/pdf_page_viewer.dart';
import 'documents_screen.dart';
import 'nav.dart';

/// Leitura da Bíblia diretamente no PDF importado, com índice por livro.
class BiblePdfScreen extends StatefulWidget {
  const BiblePdfScreen({super.key, this.book, this.chapter, this.page});
  final int? book;
  final int? chapter;
  final int? page;
  @override
  State<BiblePdfScreen> createState() => _BiblePdfScreenState();
}

class _BiblePdfScreenState extends State<BiblePdfScreen> {
  final _viewer = GlobalKey<PdfPageViewerState>();
  int? _initial;
  int _page = 1;
  int _count = 0;
  bool _full = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    if (_full) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _resolve() async {
    final app = App.I;
    int? page = widget.page;
    if (page == null && widget.book != null && widget.chapter != null) {
      page = (await app.bible.chapterInfo(widget.book!, widget.chapter!))?.pdfPage;
    }
    if (page == null && widget.book != null) {
      page = await app.bible.bookPdfPage(widget.book!);
      if (page != null && widget.chapter != null && widget.chapter! > 1) {
        _note = 'Início de ${bookById(widget.book!).name}; avance até o capítulo ${widget.chapter}.';
      } else if (page == null) {
        _note = 'Página de ${bookById(widget.book!).name} ainda não definida. Navegue até o livro e '
            'use o menu › "Definir início do livro".';
      }
    }
    page ??= app.settings.pdfPage('bible');
    setState(() {
      _initial = page;
      _page = page!;
    });
  }

  Future<void> _setBookStart() async {
    final book = await showDialog<BibleBook>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Página $_page é o início de:'),
        children: [
          for (final b in bibleBooks)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, b), child: Text(b.name)),
        ],
      ),
    );
    if (book == null) return;
    await App.I.bible.setBookPdfPage(book.id, _page);
    if (mounted) showSnack(context, '${book.name} começa na página $_page');
  }

  Future<void> _gotoBook() async {
    final b = await showDialog<BibleBook>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ir para o livro'),
        children: [
          for (final b in bibleBooks)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, b), child: Text(b.name)),
        ],
      ),
    );
    if (b == null) return;
    final page = await App.I.bible.bookPdfPage(b.id);
    if (!mounted) return;
    if (page == null) {
      showSnack(context, 'Página de ${b.name} não definida ainda.');
    } else {
      _viewer.currentState?.jumpTo(page);
    }
  }

  void _toggleFull() {
    setState(() => _full = !_full);
    SystemChrome.setEnabledSystemUIMode(_full ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final doc = App.I.documents.info(DocKind.bible);
    if (doc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bíblia (PDF)')),
        body: EmptyState(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF da Bíblia não importado',
          message: 'Importe o arquivo PDF da Bíblia ARC 1969 a partir do seu celular.',
          action: FilledButton(
            onPressed: () => push(context, const DocumentsScreen()),
            child: const Text('Importar documentos'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: _full
          ? null
          : AppBar(
              title: Text('Bíblia · p. $_page${_count > 0 ? '/$_count' : ''}'),
              actions: [
                IconButton(tooltip: 'Livros', icon: const Icon(Icons.list), onPressed: _gotoBook),
                IconButton(
                  tooltip: 'Ir para página',
                  icon: const Icon(Icons.find_in_page_outlined),
                  onPressed: () async {
                    final p = await askPage(context, max: _count, current: _page);
                    if (p != null) _viewer.currentState?.jumpTo(p);
                  },
                ),
                IconButton(tooltip: 'Tela cheia', icon: const Icon(Icons.fullscreen), onPressed: _toggleFull),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'book') _setBookStart();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'book', child: Text('Definir início do livro nesta página')),
                  ],
                ),
              ],
            ),
      floatingActionButton: _full
          ? FloatingActionButton.small(onPressed: _toggleFull, child: const Icon(Icons.fullscreen_exit))
          : null,
      body: _initial == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              if (_note != null && !_full)
                MaterialBanner(
                  content: Text(_note!),
                  actions: [TextButton(onPressed: () => setState(() => _note = null), child: const Text('OK'))],
                ),
              Expanded(
                child: PdfPageViewer(
                  key: _viewer,
                  path: doc.path,
                  initialPage: _initial!,
                  onLoaded: (n) => setState(() => _count = n),
                  onPageChanged: (p) {
                    setState(() => _page = p);
                    App.I.settings.setPdfPage('bible', p);
                  },
                ),
              ),
            ]),
    );
  }
}
