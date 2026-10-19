import 'package:flutter/material.dart';

import '../data/hymn_repository.dart';
import '../services/app_services.dart';
import '../services/documents.dart';
import '../services/pdf_text_service.dart';
import '../widgets/common.dart';

/// Mapeamento persistente entre número do hino e página do PDF.
class HymnMappingScreen extends StatefulWidget {
  const HymnMappingScreen({super.key});
  @override
  State<HymnMappingScreen> createState() => _HymnMappingScreenState();
}

class _HymnMappingScreenState extends State<HymnMappingScreen> {
  final Map<String, int> _manualCounts = {};
  String? _busy;
  String _progress = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    for (final d in Hymns.docs) {
      _manualCounts[d] = (await App.I.hymns.manualPages(d)).length;
    }
    if (mounted) setState(() {});
  }

  Future<void> _editLinear(String doc) async {
    final s = App.I.settings;
    final cur = s.linearMapping(doc);
    final first = TextEditingController(text: cur?.firstPage.toString() ?? '');
    final pph = TextEditingController(text: (cur?.pagesPerHymn ?? 1).toString());
    final choir = TextEditingController(text: cur?.choirFirstPage?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Hymns.docLabel(doc)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Use quando os hinos estão em sequência com o mesmo número de páginas. '
              'Ajustes individuais (menu do hino) têm prioridade.'),
          TextField(
              controller: first,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Página do hino 1')),
          TextField(
              controller: pph,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Páginas por hino')),
          TextField(
              controller: choir,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Página do coro 1 (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) return;
    final f = int.tryParse(first.text);
    final n = int.tryParse(pph.text) ?? 1;
    s.setLinearMapping(doc, f == null || f < 1 ? null : LinearMapping(f, n < 1 ? 1 : n, int.tryParse(choir.text)));
    setState(() {});
  }

  Future<void> _detect(String doc) async {
    final info = App.I.documents.info(DocKind.hymnal(doc));
    if (info == null) return;
    setState(() {
      _busy = doc;
      _progress = 'Lendo o PDF…';
    });
    try {
      final r = await PdfTextService.detectHymns(info.path, onProgress: (p) {
        if (mounted) setState(() => _progress = 'Página ${p.page} de ${p.pages}');
      });
      if (!mounted) return;
      if (r.pages.length < 10) {
        showSnack(context,
            'Detecção automática não confiável (${r.pages.length} hinos identificados; '
            '${r.pagesWithText} de ${r.pageCount} páginas têm texto). Use o mapeamento manual.');
        return;
      }
      final apply = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Resultado da detecção'),
          content: Text('${r.pages.length} hinos localizados em ${r.pageCount} páginas. '
              'Os hinos não localizados continuarão usando o mapeamento linear/manual. '
              'Aplicar? (ajustes manuais existentes serão mantidos)'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
          ],
        ),
      );
      if (apply == true) await App.I.applyHymnDetection(doc, r);
    } on Object catch (e) {
      if (mounted) showSnack(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = null);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.I.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Páginas dos hinos')),
      body: ListView(children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('O app não inventa títulos nem páginas. Defina onde está cada hino: '
              'pelo mapeamento linear, pela detecção automática (quando o PDF tem texto) ou '
              'abrindo o hino e escolhendo "Esta página é o hino".'),
        ),
        for (final doc in Hymns.docs) ...[
          SectionTitle(Hymns.docLabel(doc)),
          ListTile(
            leading: const Icon(Icons.linear_scale),
            title: const Text('Mapeamento linear'),
            subtitle: Text(() {
              final m = s.linearMapping(doc);
              if (m == null) return 'Não definido';
              return 'Hino 1 na p. ${m.firstPage}, ${m.pagesPerHymn} pág./hino'
                  '${m.choirFirstPage != null ? ', coro 1 na p. ${m.choirFirstPage}' : ''}';
            }()),
            onTap: () => _editLinear(doc),
          ),
          ListTile(
            leading: const Icon(Icons.edit_location_alt_outlined),
            title: const Text('Ajustes individuais'),
            subtitle: Text('${_manualCounts[doc] ?? 0} hinos com página definida'),
          ),
          ListTile(
            enabled: App.I.documents.has(DocKind.hymnal(doc)) && _busy == null,
            leading: _busy == doc
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_fix_high),
            title: const Text('Detectar automaticamente'),
            subtitle: Text(_busy == doc ? _progress : 'Procura o número do hino no topo de cada página'),
            onTap: () => _detect(doc),
          ),
        ],
      ]),
    );
  }
}
