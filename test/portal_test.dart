import 'dart:io';

import 'package:biblia_hinos_ccb/services/ccb_portal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê os links da página inicial e a data do próximo culto', () {
    const html = '''
      <div><span>Próximo Culto on-line</span> <span>21/10 às 19h30</span>
        <a href="/pedido-de-oracao">Pedir oração</a>
        <a href="https://www.youtube.com/watch?v=x"><img alt="play"></a>
        <a href="/culto-libras" title="Libras"><img></a>
        <a href="/culto-audio"><i class="fa fa-volume"></i></a>
        <a href="tel:+551100000000"><i></i></a>
      </div>
      <h2>Comunicado Importante</h2>
      <a href="/institucional"><h3>Institucional</h3><p>Histórico</p></a>
      <a href="/irmandade"><h3>Irmandade</h3></a>
      <a href="/topicos"><h3>Tópicos</h3></a>
      <a href="/culto-on-line"><h3>Culto on-line</h3></a>
      <a href="/relatorio"><h3>Relatório</h3></a>
      <a href="/ofertas"><h3>Ofertas</h3></a>''';
    final d = parsePortalHtml(html);
    expect(d.nextCulto, '21/10 às 19h30');
    expect(d.links['institucional'], 'https://congregacaocristanobrasil.org.br/institucional');
    expect(d.links['relatorio'], 'https://congregacaocristanobrasil.org.br/relatorio');
    expect(d.links['ofertas'], 'https://congregacaocristanobrasil.org.br/ofertas');
    expect(d.links['culto'], 'https://congregacaocristanobrasil.org.br/culto-on-line');
    expect(d.links['oracao'], 'https://congregacaocristanobrasil.org.br/pedido-de-oracao');
    expect(d.links['libras'], 'https://congregacaocristanobrasil.org.br/culto-libras');
    expect(d.links['audio'], 'https://congregacaocristanobrasil.org.br/culto-audio');
    expect(d.links['telefone'], 'tel:+551100000000');
    expect(d.links['video'], 'https://www.youtube.com/watch?v=x');
    expect(d.urlFor('inexistente'), ccbSite);
  });

  test('segue redirecionamentos guardando cookies', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final hasCookie = req.cookies.any((c) => c.name == 'sess' && c.value == '1');
      if (!hasCookie) {
        req.response.cookies.add(Cookie('sess', '1'));
        req.response.statusCode = 302;
        req.response.headers.set('location', '/');
      } else {
        req.response.write('<html>ok</html>');
      }
      await req.response.close();
    });
    final client = HttpClient();
    final body = await fetchWithCookies(client, Uri.parse('http://127.0.0.1:${server.port}/'));
    expect(body, '<html>ok</html>');
    client.close(force: true);
    await server.close(force: true);
  });
}
