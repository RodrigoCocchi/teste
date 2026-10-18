import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_services.dart';
import '../services/documents.dart';
import '../services/pdf_text_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Importação manual dos PDFs (Bíblia e Hinário) e indexação da Bíblia.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String? _status;
  double? _progress;
  bool get _busy => _status != null;

  void _set(String? status, [double? progress]) {
    if (mounted) {
      setState(() {
        _status = status;
        _progress = progress;
      });
    }
  }

  Future<void> _importPdf(DocKind kind) async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (files.isEmpty) return;
    final f = files.first;
    final path = f.path;
    if (path == null) {
      if (mounted) showSnack(context, 'Não foi possível acessar o arquivo selecionado.');
      return;
    }
    _set('Copiando ${f.name}…');
    try {
      await App.I.documents.import(kind, path, f.name);
      await FilePicker.clearTemporaryFiles();
      _set(null);
      if (mounted) showSnack(context, '${kind.label} importado: ${f.name}');
      if (kind == DocKind.bible && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Indexar o texto agora?'),
            content: const Text('A extração lê o texto do PDF e o organiza em livro, capítulo e '
                'versículo para permitir busca, cópia e marcações. Pode levar alguns minutos. '
                'A leitura pelo PDF já está disponível.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Depois')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Indexar')),
            ],
          ),
        );
        if (go == true) await _indexBible();
      }
    } on Object catch (e) {
      _set(null);
      if (mounted) showSnack(context, 'Falha na importação: $e');
    }
  }

  Future<void> _indexBible() async {
    final info = App.I.documents.info(DocKind.bible);
    if (info == null) return;
    _set('Lendo o PDF…', 0);
    try {
      final result = await PdfTextService.parseBible(info.path,
          onProgress: (p) => _set('Extraindo texto: página ${p.page} de ${p.pages}', p.page / p.pages));
      if (result.verses.isEmpty) {
        _set(null);
        if (mounted) {
          await _showReport('Nenhum versículo reconhecido',
              'Não foi possível estruturar o texto deste PDF (pode ser um PDF escaneado, sem '
              'camada de texto, ou com layout não reconhecido). Nada foi gravado.\n\n'
              'A leitura pelo PDF continua disponível. Alternativa: importe um arquivo JSON '
              'estruturado.\n\n${result.summary()}');
        }
        return;
      }
      _set('Gravando ${result.verses.length} versículos…', 0);
      final report = await App.I.storeBible(result, 'PDF: ${info.originalName}',
          onProgress: (p) => _set('Gravando no banco…', p));
      _set(null);
      if (mounted) await _showReport('Indexação concluída', report);
    } on Object catch (e) {
      _set(null);
      if (mounted) showSnack(context, 'Falha na indexação: $e');
    }
  }

  Future<void> _importJson() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    final path = files.isEmpty ? null : files.first.path;
    if (path == null) return;
    _set('Lendo JSON…');
    try {
      final result = App.parseBibleJson(await File(path).readAsString());
      _set('Gravando ${result.verses.length} versículos…', 0);
      final report = await App.I.storeBible(result, 'JSON: ${files.first.name}',
          onProgress: (p) => _set('Gravando no banco…', p));
      _set(null);
      if (mounted) await _showReport('Importação concluída', report);
    } on Object catch (e) {
      _set(null);
      if (mounted) showSnack(context, 'JSON inválido: $e');
    }
  }

  Future<void> _export() async {
    final dir = await getTemporaryDirectory();
    final f = await App.I.exportBibleJson(dir.path);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], title: 'Bíblia estruturada'));
  }

  Future<void> _showReport(String title, String body) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(body)),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  Widget _docTile(DocKind kind) {
    final info = App.I.documents.info(kind);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(children: [
        ListTile(
          leading: Icon(info == null ? Icons.cloud_off : Icons.check_circle,
              color: info == null ? Colors.grey : Colors.green),
          title: Text(kind.label),
          subtitle: Text(info == null
              ? 'Não importado'
              : '${info.originalName} · ${info.sizeLabel}\nImportado em '
                  '${info.importedAt.day.toString().padLeft(2, '0')}/'
                  '${info.importedAt.month.toString().padLeft(2, '0')}/${info.importedAt.year}'),
          isThreeLine: info != null,
        ),
        OverflowBar(alignment: MainAxisAlignment.end, children: [
          if (info != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await App.I.documents.remove(kind);
                      setState(() {});
                    },
              child: const Text('Remover'),
            ),
          FilledButton.tonal(
            onPressed: _busy ? null : () => _importPdf(kind),
            child: Text(info == null ? 'Importar PDF' : 'Substituir'),
          ),
          const SizedBox(width: 8),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = App.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Documentos')),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.documents, app.settings]),
        builder: (context, _) => ListView(children: [
          if (_busy)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text(_status!),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: _progress),
                ]),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Os PDFs não acompanham o aplicativo. Baixe-os das fontes oficiais ou '
                'autorizadas e selecione-os aqui. Os arquivos são copiados para a área privada do '
                'app e funcionam offline.'),
          ),
          const SectionTitle('Bíblia'),
          _docTile(DocKind.bible),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ListTile(
                leading: Icon(app.hasBibleText ? Icons.manage_search : Icons.search_off,
                    color: app.hasBibleText ? AppColors.gold : Colors.grey),
                title: const Text('Texto estruturado (busca e leitor)'),
                subtitle: Text(app.hasBibleText
                    ? '${app.verseCount} versículos · fonte: ${app.settings.bibleSource ?? '?'}'
                    : 'Não indexado'),
              ),
              if (app.settings.bibleReport != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(app.settings.bibleReport!, style: Theme.of(context).textTheme.bodySmall),
                ),
              OverflowBar(alignment: MainAxisAlignment.end, spacing: 8, children: [
                if (app.hasBibleText)
                  TextButton(onPressed: _busy ? null : _export, child: const Text('Exportar JSON')),
                TextButton(onPressed: _busy ? null : _importJson, child: const Text('Importar JSON')),
                FilledButton.tonal(
                  onPressed: _busy || !app.documents.has(DocKind.bible) ? null : _indexBible,
                  child: Text(app.hasBibleText ? 'Reindexar PDF' : 'Indexar PDF'),
                ),
                const SizedBox(width: 4),
              ]),
            ]),
          ),
          const SectionTitle('Hinário 5'),
          _docTile(DocKind.hymnalDo),
          _docTile(DocKind.hymnalOrgao),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Fontes indicadas: Bíblia ARC 1969 (cemaad.org.br; conferência em sbb.org.br) e '
              'Hinário 5 (ccbempdf.com). Respeite os direitos autorais dos documentos.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }
}
