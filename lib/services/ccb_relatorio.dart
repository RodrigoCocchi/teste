import 'dart:convert';
import 'dart:io';

import 'ccb_portal.dart';

/// Opção de lista do relatório (país, estado, cidade).
class RelOption {
  const RelOption(this.text, this.value);
  final String text;
  final String value;
}

/// Casa de oração listada nas pesquisas do relatório.
class RelPlace {
  const RelPlace({required this.id, required this.name, this.code = '', this.city = '', this.address = ''});
  final String id; // data-id, usado para abrir o detalhe
  final String name;
  final String code; // ex.: BR-21-0008
  final String city; // ex.: São Paulo, SP, Brasil
  final String address;
}

class RelPage {
  const RelPage(this.places, this.info, this.hasNext);
  final List<RelPlace> places;
  final String? info; // ex.: "Exibindo 5 de 13"
  final bool hasNext;
}

/// Filtros da pesquisa de cultos (vazio = todos).
class RelFilter {
  const RelFilter({this.tipos = const {}, this.dias = const {}, this.periodos = const {}});
  final Set<String> tipos;
  final Set<int> dias; // 1 = domingo ... 7 = sábado
  final Set<String> periodos;
}

/// Bloco do detalhe: título (ex.: "Localização", "Dias de Culto") e linhas.
class RelSection {
  const RelSection(this.title, this.lines);
  final String title;
  final List<String> lines;
}

const List<String> relTiposCulto = ['Culto Oficial', 'Reunião de Jovens e Menores'];
const List<String> relPeriodos = ['Manhã', 'Tarde', 'Noite'];
const List<String> relDias = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

String relText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Converte o HTML devolvido pelas pesquisas do relatório em casas de oração.
RelPage parseRelTable(String html) {
  final places = <RelPlace>[];
  final starts = RegExp(r'''data-id\s*=\s*["']([^"']+)["']''').allMatches(html).toList();
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1].start : html.length;
    var block = html.substring(starts[i].end, end);
    final close = block.indexOf('</td>');
    if (close >= 0) block = block.substring(0, close);
    final name = RegExp(r'<strong[^>]*>(.*?)</strong>', dotAll: true).firstMatch(block)?[1];
    final code = RegExp(r'<small[^>]*>(.*?)</small>', dotAll: true).firstMatch(block)?[1];
    final divs = RegExp(r'<div[^>]*>([^<]*)</div>')
        .allMatches(block)
        .map((m) => relText(m[1]!))
        .where((t) => t.isNotEmpty)
        .toList();
    places.add(RelPlace(
      id: starts[i][1]!,
      name: relText(name ?? (divs.isEmpty ? '' : divs.first)),
      code: relText(code ?? ''),
      city: divs.isNotEmpty ? divs.first : '',
      address: divs.length > 1 ? divs[1] : '',
    ));
  }
  final text = relText(html);
  final info = RegExp(r'Exibindo\s+\d+\s+de\s+\d+', caseSensitive: false).firstMatch(text)?[0];
  final hasNext = RegExp(r'<button[^>]*value="\d+"[^>]*>\s*Pr[óo]ximo', caseSensitive: false).hasMatch(html);
  return RelPage(places, info, hasNext);
}

/// Detalhe da casa de oração em blocos (localização, dias de culto, ministério, telefones).
List<RelSection> parseRelDetail(String html) {
  final out = <RelSection>[];
  for (final card in html.split(RegExp(r'<div class="card detalhe">')).skip(1)) {
    final title = relText(RegExp(r'<label[^>]*>(.*?)</label>', dotAll: true).firstMatch(card)?[1] ?? '');
    final lines = <String>[];
    for (final m in RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true).allMatches(card)) {
      final t = relText(m[1]!);
      // O site repete nomes seguidos no ministério.
      if (t.isNotEmpty && (lines.isEmpty || lines.last != t)) lines.add(t);
    }
    if (title.isNotEmpty || lines.isNotEmpty) out.add(RelSection(title, lines));
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
    RelFilter filter = const RelFilter(),
    int pagina = 1,
  }) async =>
      parseRelTable(await _post('servico-relatorio', {
        'codigoPais': pais,
        'codigoEstado': estado,
        'codigoCidade': cidade,
        // O site não devolve nada com filtro vazio: "todos" = todas as opções marcadas.
        'tipoCulto': (filter.tipos.isEmpty ? relTiposCulto : filter.tipos).join(','),
        'diaSemana': (filter.dias.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : (filter.dias.toList()..sort())).join(','),
        'periodo': (filter.periodos.isEmpty ? relPeriodos : filter.periodos).join(','),
        'pagina': '$pagina',
      }));

  Future<List<RelSection>> detalhe(String codigo) async =>
      parseRelDetail(await _post('localidade-detalhe', {'codigo': codigo}));

  void close() {
    _client?.close(force: true);
    _client = null;
  }
}
