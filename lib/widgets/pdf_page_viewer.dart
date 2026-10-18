import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Visualizador de PDF página a página: renderiza sob demanda (o arquivo não
/// é carregado inteiro na memória) e permite zoom por gesto.
class PdfPageViewer extends StatefulWidget {
  const PdfPageViewer({super.key, required this.path, this.initialPage = 1, this.onPageChanged, this.onLoaded});
  final String path;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onLoaded;

  @override
  State<PdfPageViewer> createState() => PdfPageViewerState();
}

class PdfPageViewerState extends State<PdfPageViewer> {
  late PdfController _controller;
  int _pages = 0;

  int get page => _controller.page;
  int get pageCount => _pages;

  @override
  void initState() {
    super.initState();
    _controller = PdfController(
      document: PdfDocument.openFile(widget.path),
      initialPage: widget.initialPage < 1 ? 1 : widget.initialPage,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void jumpTo(int page) {
    if (_pages == 0) return;
    _controller.jumpToPage(page.clamp(1, _pages));
  }

  @override
  Widget build(BuildContext context) {
    return PdfView(
      controller: _controller,
      backgroundDecoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer),
      onDocumentLoaded: (doc) {
        setState(() => _pages = doc.pagesCount);
        widget.onLoaded?.call(doc.pagesCount);
      },
      onPageChanged: widget.onPageChanged,
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Não foi possível abrir o PDF.\n$error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

Future<int?> askPage(BuildContext context, {required int max, int? current, String title = 'Ir para a página'}) async {
  final ctrl = TextEditingController(text: current?.toString() ?? '');
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: max > 0 ? '1 a $max' : 'Número da página'),
        onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)), child: const Text('OK')),
      ],
    ),
  );
}
