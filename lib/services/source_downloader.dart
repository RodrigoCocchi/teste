import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'documents.dart';

/// Endereços indicados para cada documento.
const Map<DocKind, String> officialSources = {
  DocKind.bible:
      'https://cemaad.org.br/wp-content/uploads/2023/01/Biblia-Almeida-Revista-e-Corrigida-1969.pdf',
  DocKind.hymnalDo: 'https://www.ccbempdf.com/2021/06/hinario-n5-ccb-do-em-pdf.html',
  DocKind.hymnalOrgao: 'https://www.ccbempdf.com/2021/07/hinario-n5-ccb-orgao-em-pdf.html',
};

class DownloadProgress {
  const DownloadProgress(this.message, [this.fraction]);
  final String message;
  final double? fraction;
}

class DownloadFailure implements Exception {
  DownloadFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Baixa o PDF direto da fonte, no próprio celular. Quando o endereço é uma
/// página (blog), procura no conteúdo da postagem o link real do PDF
/// (arquivo .pdf ou Google Drive) e valida que o arquivo baixado é um PDF.
class SourceDownloader {
  SourceDownloader({HttpClient? client}) : _client = client ?? HttpClient() {
    _client
      ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36'
      ..connectionTimeout = const Duration(seconds: 25);
  }

  final HttpClient _client;

  /// Baixa [url] para [dest]. Retorna o endereço de onde o PDF veio.
  Future<String> download(String url, String dest,
      {void Function(DownloadProgress)? onProgress, String? prefer}) async {
    onProgress?.call(const DownloadProgress('Conectando…'));
    final first = await _fetch(Uri.parse(url), dest, onProgress);
    if (first == null) return url; // já era PDF
    final candidates = extractPdfLinks(first, Uri.parse(url), prefer: prefer);
    if (candidates.isEmpty) {
      throw DownloadFailure('Não encontrei o link do PDF na página.');
    }
    for (final c in candidates.take(6)) {
      onProgress?.call(DownloadProgress('Baixando de ${c.host}…'));
      try {
        final html = await _fetch(c, dest, onProgress);
        if (html == null) return c.toString();
        // Google Drive: página de confirmação para arquivos grandes.
        final confirm = driveConfirmUrl(html);
        if (confirm != null && await _fetch(confirm, dest, onProgress) == null) {
          return confirm.toString();
        }
      } on DownloadFailure {
        continue;
      } on IOException {
        continue;
      }
    }
    throw DownloadFailure('Os links encontrados na página não entregaram um PDF.');
  }

  /// Faz o download. Se a resposta for PDF, grava em [dest] e retorna null;
  /// se for HTML, retorna o texto da página.
  Future<String?> _fetch(Uri uri, String dest, void Function(DownloadProgress)? onProgress) async {
    final req = await _client.getUrl(uri);
    req.followRedirects = true;
    req.maxRedirects = 10;
    final res = await req.close().timeout(const Duration(seconds: 40));
    if (res.statusCode >= 400) {
      await res.drain<void>();
      throw DownloadFailure('O servidor respondeu ${res.statusCode} para ${uri.host}.');
    }
    final total = res.contentLength;
    final tmp = File('$dest.part');
    final sink = tmp.openWrite();
    var received = 0;
    var header = <int>[];
    var isPdf = false;
    final html = BytesBuilder(copy: false);
    try {
      await for (final chunk in res.timeout(const Duration(seconds: 60))) {
        if (header.length < 5) {
          header = [...header, ...chunk.take(5 - header.length)];
          if (header.length >= 5) isPdf = String.fromCharCodes(header) == '%PDF-';
        }
        received += chunk.length;
        if (isPdf || header.length < 5) {
          sink.add(chunk);
        }
        if (!isPdf && header.length >= 5) {
          html.add(chunk);
          if (html.length > 3 * 1024 * 1024) break;
        }
        if (isPdf) {
          onProgress?.call(DownloadProgress(
              'Baixando: ${(received / 1048576).toStringAsFixed(1)} MB'
              '${total > 0 ? ' de ${(total / 1048576).toStringAsFixed(1)} MB' : ''}',
              total > 0 ? received / total : null));
        }
      }
    } finally {
      await sink.close();
    }
    if (isPdf) {
      if (received < 50 * 1024) {
        await tmp.delete();
        throw DownloadFailure('Arquivo baixado é pequeno demais para ser o documento.');
      }
      await tmp.rename(dest);
      return null;
    }
    final firstBytes = (await tmp.exists()) ? await tmp.readAsBytes() : <int>[];
    if (await tmp.exists()) await tmp.delete();
    return utf8.decode([...firstBytes, ...html.takeBytes()], allowMalformed: true);
  }

  void close() => _client.close(force: true);
}

final _href = RegExp(r'''(?:href|src)\s*=\s*["']([^"']+)["']''', caseSensitive: false);
final _driveId = RegExp(r'''drive\.google\.com/(?:file/d/|open\?id=|uc\?(?:[^"'\s]*&)?id=)([\w-]{20,})''');
final _docsId = RegExp(r'''docs\.google\.com/(?:uc\?(?:[^"'\s]*&)?id=|file/d/)([\w-]{20,})''');

/// Extrai links de PDF de uma página. Se houver o corpo da postagem
/// (Blogger/WordPress), procura somente nele, para não pegar links da
/// barra lateral. [prefer] prioriza links/textos que contenham o termo.
List<Uri> extractPdfLinks(String html, Uri base, {String? prefer}) {
  var body = html;
  for (final marker in const ['post-body', 'entry-content', '<article']) {
    final i = html.indexOf(marker);
    if (i >= 0) {
      body = html.substring(i);
      final end = body.indexOf(RegExp(r"class=.(post-footer|blog-pager|comments)"));
      if (end > 0) body = body.substring(0, end);
      break;
    }
  }
  final out = <Uri>[];
  void add(Uri u) {
    if (!out.any((x) => x.toString() == u.toString())) out.add(u);
  }

  for (final m in _href.allMatches(body)) {
    final raw = m[1]!.replaceAll('&amp;', '&');
    final id = _driveId.firstMatch(raw)?[1] ?? _docsId.firstMatch(raw)?[1];
    if (id != null) {
      add(Uri.parse('https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t'));
      continue;
    }
    if (RegExp(r'\.pdf(\?|#|$)', caseSensitive: false).hasMatch(raw)) {
      add(base.resolve(raw));
    }
  }
  if (prefer != null) {
    final p = prefer.toLowerCase();
    out.sort((a, b) => (b.toString().toLowerCase().contains(p) ? 1 : 0)
        .compareTo(a.toString().toLowerCase().contains(p) ? 1 : 0));
  }
  return out;
}

/// Página de aviso do Google Drive ("não foi possível verificar vírus"):
/// monta a URL do formulário de confirmação.
Uri? driveConfirmUrl(String html) {
  final form = RegExp(r'<form[^>]*id="download-form"[^>]*action="([^"]+)"', caseSensitive: false)
      .firstMatch(html);
  if (form == null) return null;
  final params = <String, String>{
    for (final m in RegExp(r'<input[^>]*type="hidden"[^>]*name="([^"]+)"[^>]*value="([^"]*)"')
        .allMatches(html))
      m[1]!: m[2]!,
  };
  return Uri.parse(form[1]!.replaceAll('&amp;', '&')).replace(queryParameters: params);
}
