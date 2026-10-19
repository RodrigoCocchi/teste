import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/text_utils.dart';

/// Atalhos para o site oficial da CCB. Os endereços são lidos da página
/// inicial do site (e guardados), para acompanhar mudanças sem atualizar o app.
class PortalLink {
  const PortalLink(this.key, this.title, this.subtitle, this.keywords);
  final String key;
  final String title;
  final String subtitle;

  /// Palavras (sem acento) que identificam o link no texto ou no endereço.
  final List<String> keywords;
}

const String ccbSite = 'https://congregacaocristanobrasil.org.br';

const List<PortalLink> portalSections = [
  PortalLink('institucional', 'Institucional', 'Histórico, Estatuto, Esclarecimentos e Contato', ['institucional']),
  PortalLink('irmandade', 'Irmandade', 'Circulares e tópicos de ensinamento', ['irmandade']),
  PortalLink('topicos', 'Tópicos', 'Tópicos de Ensinamentos', ['topicos']),
  PortalLink('culto', 'Culto on-line', 'Para enfermos e pertencentes a grupos de risco', ['culto on-line', 'culto online', 'culto-on-line']),
  PortalLink('relatorio', 'Relatório', 'Relatório Digital e aplicativos', ['relatorio']),
  PortalLink('ofertas', 'Ofertas', 'Realizar oferta', ['ofertas', 'oferta']),
];

/// Botões do bloco "Próximo Culto on-line".
const List<PortalLink> cultoButtons = [
  PortalLink('video', 'Assistir', 'Vídeo do culto', ['youtube', 'video', 'assistir']),
  PortalLink('libras', 'Libras', 'Culto em Libras', ['libras']),
  PortalLink('audio', 'Ouvir', 'Somente áudio', ['audio', 'radio', 'ouvir']),
  PortalLink('telefone', 'Telefone', 'Ouvir por telefone', ['tel:', 'telefone']),
  PortalLink('oracao', 'Pedir oração', 'Enviar pedido de oração', ['oracao', 'pedido']),
];

class PortalData {
  PortalData(this.links, this.nextCulto, this.updatedAt);
  final Map<String, String> links;
  final String? nextCulto; // ex.: "21/10 às 19h30"
  final DateTime? updatedAt;

  String urlFor(String key) => links[key] ?? ccbSite;
}

/// Extrai os links e a data do próximo culto do HTML da página inicial.
PortalData parsePortalHtml(String html, {Uri? base}) {
  final b = base ?? Uri.parse(ccbSite);
  final anchors = <(int, String, String)>[]; // posição, href, texto normalizado
  for (final m in RegExp(r'<a\b([^>]*)>(.*?)</a>', dotAll: true, caseSensitive: false).allMatches(html)) {
    final href = RegExp(r'''href\s*=\s*["']([^"']+)["']''', caseSensitive: false).firstMatch(m[1]!)?[1];
    if (href == null || href.startsWith('#') || href.startsWith('javascript')) continue;
    final attrs = RegExp(r'''(?:title|aria-label|alt)\s*=\s*["']([^"']+)["']''', caseSensitive: false)
        .allMatches(m[0]!)
        .map((x) => x[1])
        .join(' ');
    final text = normalize('${m[2]!.replaceAll(RegExp(r'<[^>]+>'), ' ')} $attrs')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final abs = href.startsWith('tel:') || href.startsWith('mailto:') ? href : b.resolve(href).toString();
    anchors.add((m.start, abs, text));
  }
  final links = <String, String>{};
  bool matches((int, String, String) a, PortalLink l) {
    final href = normalize(a.$2);
    return l.keywords.any((k) => a.$3.contains(k) || href.contains(k.replaceAll(' ', '-')));
  }

  for (final l in portalSections) {
    // Prefere o link cujo texto é a seção (o card), depois o endereço.
    final byText = anchors.where((a) => l.keywords.any((k) => a.$3.startsWith(k))).lastOrNull;
    final hit = byText ?? anchors.where((a) => matches(a, l)).firstOrNull;
    if (hit != null) links[l.key] = hit.$2;
  }
  // Botões do bloco do próximo culto: links entre "Próximo Culto" e o bloco seguinte.
  final lower = normalize(html);
  final start = lower.indexOf('proximo culto');
  if (start >= 0) {
    var end = lower.indexOf('comunicado', start);
    if (end < 0) end = start + 6000;
    final block = anchors.where((a) => a.$1 >= start - 200 && a.$1 <= end).toList();
    for (final l in cultoButtons) {
      final hit = block.where((a) => matches(a, l)).firstOrNull;
      if (hit != null) links[l.key] = hit.$2;
    }
    // Vídeo: primeiro link do bloco que não é nenhum dos outros.
    if (!links.containsKey('video')) {
      final used = links.values.toSet();
      final other = block.where((a) => !used.contains(a.$2)).firstOrNull;
      if (other != null) links['video'] = other.$2;
    }
  }
  final text = html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  final date = RegExp(r'Pr[óo]ximo Culto on-?line\s*(\d{1,2}/\d{1,2}\s*[àa]s\s*\d{1,2}h\d{0,2})', caseSensitive: false)
      .firstMatch(text)?[1];
  return PortalData(links, date, DateTime.now());
}

/// GET seguindo redirecionamentos manualmente e guardando os cookies (o site
/// da CCB redireciona em círculo para clientes que não guardam cookies).
Future<String> fetchWithCookies(HttpClient client, Uri start, {Map<String, String>? jar}) async {
  final cookies = jar ?? <String, String>{};
  var uri = start;
  for (var i = 0; i < 12; i++) {
    final req = await client.getUrl(uri);
    req.followRedirects = false;
    req.headers.set(HttpHeaders.acceptHeader, 'text/html,application/json;q=0.9,*/*;q=0.8');
    req.headers.set(HttpHeaders.acceptLanguageHeader, 'pt-BR,pt;q=0.9');
    if (cookies.isNotEmpty) {
      req.headers.set(HttpHeaders.cookieHeader, cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
    }
    final res = await req.close().timeout(const Duration(seconds: 30));
    for (final c in res.cookies) {
      cookies[c.name] = c.value;
    }
    if (res.isRedirect || (res.statusCode >= 300 && res.statusCode < 400)) {
      final loc = res.headers.value(HttpHeaders.locationHeader);
      await res.drain<void>();
      if (loc == null) break;
      uri = uri.resolve(loc);
      continue;
    }
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 400) throw HttpException('Site respondeu ${res.statusCode}');
    return body;
  }
  throw const HttpException('Muitos redirecionamentos');
}

class CcbPortal {
  CcbPortal(this._prefs);
  final SharedPreferences _prefs;

  PortalData get cached {
    final raw = _prefs.getString('portalLinks');
    final links = raw == null ? <String, String>{} : Map<String, String>.from(jsonDecode(raw) as Map);
    final at = _prefs.getInt('portalAt');
    return PortalData(links, _prefs.getString('portalCulto'),
        at == null ? null : DateTime.fromMillisecondsSinceEpoch(at));
  }

  /// Lê a página inicial do site e atualiza os links guardados.
  Future<PortalData> refresh() async {
    final client = HttpClient()
      ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36'
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final html = await fetchWithCookies(client, Uri.parse('$ccbSite/'));
      final data = parsePortalHtml(html);
      if (data.links.isNotEmpty) {
        await _prefs.setString('portalLinks', jsonEncode(data.links));
        await _prefs.setInt('portalAt', DateTime.now().millisecondsSinceEpoch);
      }
      if (data.nextCulto != null) await _prefs.setString('portalCulto', data.nextCulto!);
      return cached;
    } finally {
      client.close(force: true);
    }
  }
}
