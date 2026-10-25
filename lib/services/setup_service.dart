import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'app_services.dart';
import 'documents.dart';
import 'pdf_text_service.dart';
import 'source_downloader.dart';

enum SetupState { pending, running, done, failed }

/// Uma etapa da preparação automática (mostrada na tela de preparação).
class SetupStep {
  SetupStep(this.title);
  final String title;
  SetupState state = SetupState.pending;
  String message = 'Aguardando';
  double? progress;
}

/// Preparação automática no primeiro uso: baixa os PDFs das fontes indicadas,
/// organiza a Bíblia e localiza os hinos, sem precisar de nenhum toque.
/// Etapas que falham são repetidas automaticamente e retomadas na próxima
/// abertura do app.
class SetupService extends ChangeNotifier {
  SetupService(this._app);
  final App _app;

  final bibleDownload = SetupStep('Baixar a Bíblia');
  final bibleIndex = SetupStep('Organizar livros, capítulos e versículos');
  final doDownload = SetupStep('Baixar o Hinário 5 em Dó');
  final orgaoDownload = SetupStep('Baixar o Hinário 5 para órgão');
  final cantoDownload = SetupStep('Baixar o Hinário 5 só canto');

  List<SetupStep> get steps => [bibleDownload, bibleIndex, doDownload, orgaoDownload, cantoDownload];

  /// Desligado nos testes de interface (sem rede).
  static bool autoStart = true;

  bool running = false;
  String? lastReport;

  static const _retryDelays = [5, 20, 60];

  /// Falta algo para o app ficar completo?
  bool get needed =>
      !_app.documents.has(DocKind.bible) ||
      !_app.hasBibleText ||
      !_app.documents.has(DocKind.hymnalDo) ||
      !_app.documents.has(DocKind.hymnalOrgao) ||
      !_app.documents.has(DocKind.hymnalCanto);

  bool get finished => steps.every((s) => s.state == SetupState.done);

  String get headline {
    final current = steps.where((s) => s.state == SetupState.running).firstOrNull;
    if (current != null) return '${current.title}: ${current.message}';
    if (finished) return 'Tudo pronto! O aplicativo já funciona sem internet.';
    if (steps.any((s) => s.state == SetupState.failed)) {
      return 'Algumas etapas não foram concluídas. Tentaremos de novo na próxima abertura.';
    }
    return 'Preparando o aplicativo…';
  }

  void _update(SetupStep s, SetupState state, String message, [double? progress]) {
    s
      ..state = state
      ..message = message
      ..progress = progress;
    notifyListeners();
  }

  /// Executa todas as etapas pendentes (idempotente).
  Future<void> run() async {
    if (running) return;
    running = true;
    notifyListeners();
    try {
      _markDone();
      if (!_app.documents.has(DocKind.bible)) {
        await _withRetry(bibleDownload, () => download(DocKind.bible, step: bibleDownload));
      }
      if (_app.documents.has(DocKind.bible) && !_app.hasBibleText) {
        await _withRetry(bibleIndex, () => indexBible(step: bibleIndex), attempts: 1);
      }
      for (final (kind, step) in [
        (DocKind.hymnalDo, doDownload),
        (DocKind.hymnalOrgao, orgaoDownload),
        (DocKind.hymnalCanto, cantoDownload),
      ]) {
        if (!_app.documents.has(kind)) {
          await _withRetry(step, () => download(kind, step: step));
        }
      }
      _markDone();
    } finally {
      running = false;
      notifyListeners();
    }
  }

  void _markDone() {
    if (_app.documents.has(DocKind.bible)) _update(bibleDownload, SetupState.done, 'Concluído');
    if (_app.hasBibleText) _update(bibleIndex, SetupState.done, '${_app.verseCount} versículos');
    if (_app.documents.has(DocKind.hymnalDo)) _update(doDownload, SetupState.done, 'Concluído');
    if (_app.documents.has(DocKind.hymnalOrgao)) _update(orgaoDownload, SetupState.done, 'Concluído');
    if (_app.documents.has(DocKind.hymnalCanto)) _update(cantoDownload, SetupState.done, 'Concluído');
  }

  Future<void> _withRetry(SetupStep step, Future<void> Function() task, {int attempts = 4}) async {
    for (var i = 0; i < attempts; i++) {
      try {
        await task();
        return;
      } on Object catch (e) {
        if (i == attempts - 1) {
          _update(step, SetupState.failed, 'Não foi possível concluir: $e');
          return;
        }
        final wait = _retryDelays[i.clamp(0, _retryDelays.length - 1)];
        _update(step, SetupState.running, 'Falhou, tentando de novo em ${wait}s…');
        await Future<void>.delayed(Duration(seconds: wait));
      }
    }
  }

  /// Baixa o documento da fonte indicada e, para hinários, localiza os hinos.
  Future<void> download(DocKind kind, {SetupStep? step}) async {
    void report(String m, [double? p]) {
      if (step != null) _update(step, SetupState.running, m, p);
    }

    final url = officialSources[kind]!;
    final dest = '${(await getTemporaryDirectory()).path}/${kind.key}_download.pdf';
    final downloader = SourceDownloader();
    try {
      report('Conectando…');
      final from = await downloader.download(url, dest,
          prefer: kind == DocKind.hymnalOrgao ? 'orgao' : null,
          onProgress: (p) => report(p.message, p.fraction));
      final last = Uri.parse(from).pathSegments.lastOrNull ?? '';
      final name = last.toLowerCase().endsWith('.pdf') ? Uri.decodeComponent(last) : '${kind.label}.pdf';
      await _app.documents.import(kind, dest, name);
      await File(dest).delete();
    } finally {
      downloader.close();
    }
    if (kind != DocKind.bible) {
      final n = await detectHymns(kind, onProgress: report);
      if (step != null) {
        _update(step, SetupState.done,
            n > 0 ? '$n hinos localizados' : 'Baixado (páginas dos hinos: mapear manualmente)');
      }
    } else if (step != null) {
      _update(step, SetupState.done, 'Concluído');
    }
  }

  /// Localiza páginas e títulos dos hinos. Retorna quantos foram mapeados.
  Future<int> detectHymns(DocKind kind, {void Function(String, [double?])? onProgress}) async {
    final info = _app.documents.info(kind);
    if (info == null) return 0;
    try {
      final d = await PdfTextService.detectHymns(info.path,
          onProgress: (p) => onProgress?.call('Localizando os hinos (página ${p.page} de ${p.pages})',
              p.page / p.pages));
      if (d.pages.length < 50) return 0; // pouco confiável: fica o mapeamento manual
      return await _app.applyHymnDetection(kind.key, d);
    } on Object {
      return 0;
    }
  }

  /// Extrai e organiza o texto da Bíblia. Retorna o relatório.
  Future<String> indexBible({SetupStep? step, void Function(String, [double?])? onProgress}) async {
    void report(String m, [double? p]) {
      onProgress?.call(m, p);
      if (step != null) _update(step, SetupState.running, m, p);
    }

    final info = _app.documents.info(DocKind.bible);
    if (info == null) throw StateError('PDF da Bíblia não importado');
    report('Lendo o PDF…', 0);
    final result = await PdfTextService.parseBible(info.path,
        onProgress: (p) => report('Lendo página ${p.page} de ${p.pages}', p.page / p.pages));
    if (result.verses.isEmpty) {
      throw StateError('nenhum versículo reconhecido neste PDF (a leitura pelo PDF continua disponível)');
    }
    report('Gravando ${result.verses.length} versículos…', 0);
    final text = await _app.storeBible(result, 'PDF: ${info.originalName}',
        onProgress: (p) => report('Gravando versículos…', p));
    lastReport = text;
    if (step != null) _update(step, SetupState.done, '${_app.verseCount} versículos');
    return text;
  }
}
