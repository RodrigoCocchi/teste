import 'dart:convert';
import 'dart:io';

import 'ccb_portal.dart';

/// Opção de lista do relatório (país, estado, cidade).
class RelOption {
  const RelOption(this.text, this.value);
  final String text;
  final String value;
}

/// Linha de resultado das tabelas do relatório.
class RelRow {
  const RelRow(this.id, this.cells);
  final String? id; // data-id, usado para abrir o detalhe
  final List<String> cells;
}

class RelPage {
  const RelPage(this.headers, this.rows, this.info);
  final List<String> headers;
  final List<RelRow> rows;
  final String? info; // ex.: "Exibindo 20 de 24254"
}

const List<String> relTiposCulto = ['Culto Oficial', 'Reunião de Jovens e Menores'];
const List<String> relPeriodos = ['Manhã', 'Tarde', 'Noite'];
const List<String> relDias = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

String _cellText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' · ')
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'^[\s·]+|[\s·]+$'), '')
    .trim();

/// Converte o HTML devolvido pelos serviços do relatório em linhas de tabela.
RelPage parseRelTable(String html) {
  final headers = RegExp(r'<th\b[^>]*>(.*?)</th>', dotAll: true, caseSensitive: false)
      .allMatches(html)
      .map((m) => _cellText(m[1]!))
      .toList();
  final rows = <RelRow>[];
  for (final m in RegExp(r'<tr\b([^>]*)>(.*?)</tr>', dotAll: true, caseSensitive: false).allMatches(html)) {
    final cells = RegExp(r'<td\b[^>]*>(.*?)</td>', dotAll: true, caseSensitive: false)
        .allMatches(m[2]!)
        .map((c) => _cellText(c[1]!))
        .toList();
    if (cells.isEmpty || cells.every((c) => c.isEmpty)) continue;
    final id = RegExp(r'''data-id\s*=\s*["']([^"']+)["']''').firstMatch(m[0]!)?[1];
    rows.add(RelRow(id, cells));
  }
  final text = _cellText(html);
  final info = RegExp(r'Exibindo\s+\d+\s+de\s+\d+', caseSensitive: false).firstMatch(text)?[0];
  return RelPage(headers, rows, info);
}

/// Detalhe da casa de oração: pares "rótulo: valor" do HTML.
List<(String, String)> parseRelDetail(String html) {
  final out = <(String, String)>[];
  for (final m in RegExp(r'<tr\b[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false).allMatches(html)) {
    final cells = RegExp(r'<t[hd]\b[^>]*>(.*?)</t[hd]>', dotAll: true, caseSensitive: false)
        .allMatches(m[1]!)
        .map((c) => _cellText(c[1]!))
        .where((c) => c.isNotEmpty)
        .toList();
    if (cells.length >= 2) {
      out.add((cells.first, cells.skip(1).join(' · ')));
    } else if (cells.length == 1) {
      out.add(('', cells.first));
    }
  }
  if (out.isEmpty) {
    for (final line in html.split(RegExp(r'<br\s*/?>|</p>|</div>|</li>|</h\d>', caseSensitive: false))) {
      final t = _cellText(line);
      if (t.isEmpty) continue;
      final i = t.indexOf(':');
      out.add(i > 0 && i < 40 ? (t.substring(0, i).trim(), t.substring(i + 1).trim()) : ('', t));
    }
  }
  return out;
}

List<RelOption> parseRelOptions(String body) {
  final j = jsonDecode(body);
  final list = j is Map ? j['list'] : j;
  if (list is! List) return const [];
  return [
    for (final it in list)
      if (it is Map && '${it['Value'] ?? ''}'.isNotEmpty && '${it['Value']}' != '0')
        RelOption('${it['Text']}', '${it['Value']}'),
  ];
}

/// Cliente dos serviços de pesquisa da página /relatorio do site da CCB.
class CcbRelatorio {
  final Map<String, String> _jar = {};
  String? _token;
  HttpClient? _client;

  HttpClient get _http => _client ??= HttpClient()
    ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36'
    ..connectionTimeout = const Duration(seconds: 20);

  Future<void> _ensureSession() async {
    if (_token != null) return;
    final html = await fetchWithCookies(_http, Uri.parse('$ccbSite/relatorio'), jar: _jar);
    _token = RegExp(r'name="__RequestVerificationToken"[^>]*value="([^"]+)"').firstMatch(html)?[1] ??
        RegExp(r'value="([^"]+)"[^>]*name="__RequestVerificationToken"').firstMatch(html)?[1] ??
        '';
  }

  Future<String> _post(String service, Map<String, String> data, {bool retry = true}) async {
    await _ensureSession();
    final req = await _http.postUrl(Uri.parse('$ccbSite/service/$service'));
    req.followRedirects = false;
    req.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded; charset=UTF-8')
      ..set('X-Requested-With', 'XMLHttpRequest')
      ..set('AntiForgeryToken', _token ?? '')
      ..set(HttpHeaders.cookieHeader, _jar.entries.map((e) => '${e.key}=${e.value}').join('; '));
    req.write(Uri(queryParameters: data).query);
    final res = await req.close().timeout(const Duration(seconds: 40));
    for (final c in res.cookies) {
      _jar[c.name] = c.value;
    }
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      if (retry) {
        _token = null; // sessão expirada: abre de novo e repete uma vez
        return _post(service, data, retry: false);
      }
      throw HttpException('Site respondeu ${res.statusCode}');
    }
    return body;
  }

  Future<List<RelOption>> paises() async => parseRelOptions(await _post('pais-relatorio', {}));
  Future<List<RelOption>> estados(String pais) async =>
      parseRelOptions(await _post('estado-relatorio', {'codigoPais': pais}));
  Future<List<RelOption>> cidades(String estado) async =>
      parseRelOptions(await _post('cidade-relatorio', {'codigoEstado': estado}));

  /// Pesquisa pelo nome da casa de oração (bairro, localidade).
  Future<RelPage> localidades(String search, {int pagina = 1}) async =>
      parseRelTable(await _post('localidade-relatorio', {'search': search, 'pagina': '$pagina'}));

  /// Pesquisa de cultos por local, tipo, dia e período.
  Future<RelPage> servicos({
    required String pais,
    String estado = '',
    String cidade = '',
    Set<String> tipos = const {},
    int? dia, // 1 = domingo ... 7 = sábado
    String periodo = '',
    int pagina = 1,
  }) async =>
      parseRelTable(await _post('servico-relatorio', {
        'codigoPais': pais,
        'codigoEstado': estado,
        'codigoCidade': cidade,
        'tipoCulto': tipos.join(','),
        'diaSemana': dia == null ? '' : '$dia',
        'periodo': periodo,
        'pagina': '$pagina',
      }));

  Future<List<(String, String)>> detalhe(String codigo) async =>
      parseRelDetail(await _post('localidade-detalhe', {'codigo': codigo}));

  void close() {
    _client?.close(force: true);
    _client = null;
  }
}
