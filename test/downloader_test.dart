import 'dart:io';
import 'dart:typed_data';

import 'package:biblia_hinos_ccb/services/source_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

/// PDF falso (só o cabeçalho importa para a validação do download).
Uint8List fakePdf() => Uint8List.fromList([...'%PDF-1.4\n'.codeUnits, ...List.filled(80 * 1024, 32)]);

void main() {
  test('extrai links de PDF e do Google Drive somente do corpo da postagem', () {
    const html = '''
      <div class="sidebar"><a href="https://site/outro-hinario.pdf">outro</a></div>
      <div class="post-body entry-content">
        <a href="https://drive.google.com/file/d/1AbCdEfGhIjKlMnOpQrStUvWxYz123/view?usp=sharing">Baixar</a>
        <a href="/arquivos/hinario-orgao.pdf">PDF</a>
      </div>
      <div class="post-footer"><a href="https://site/rodape.pdf">x</a></div>''';
    final links = extractPdfLinks(html, Uri.parse('https://www.exemplo.com/2021/07/p.html'));
    expect(links.map((u) => u.toString()), [
      'https://drive.usercontent.google.com/download?id=1AbCdEfGhIjKlMnOpQrStUvWxYz123&export=download&confirm=t',
      'https://www.exemplo.com/arquivos/hinario-orgao.pdf',
    ]);
    final pref = extractPdfLinks(html, Uri.parse('https://www.exemplo.com/'), prefer: 'orgao');
    expect(pref.first.path, '/arquivos/hinario-orgao.pdf');
  });

  test('monta a URL de confirmação do Google Drive', () {
    const html = '<form id="download-form" action="https://drive.usercontent.google.com/download" method="get">'
        '<input type="hidden" name="id" value="ABC"><input type="hidden" name="confirm" value="t">'
        '<input type="hidden" name="uuid" value="u1"></form>';
    final u = driveConfirmUrl(html)!;
    expect(u.host, 'drive.usercontent.google.com');
    expect(u.queryParameters, {'id': 'ABC', 'confirm': 't', 'uuid': 'u1'});
  });

  group('download por servidor local', () {
    late HttpServer server;
    late String base;
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('bh_dl');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}';
      server.listen((req) async {
        switch (req.uri.path) {
          case '/direto.pdf':
          case '/arquivo/hinario.pdf':
            req.response.headers.contentType = ContentType('application', 'pdf');
            req.response.add(fakePdf());
          case '/redir':
            req.response.redirect(Uri.parse('$base/direto.pdf'));
            return;
          case '/pagina.html':
            req.response.headers.contentType = ContentType.html;
            req.response.write('<div class="post-body"><a href="/quebrado.pdf">a</a>'
                '<a href="/arquivo/hinario.pdf">b</a></div>');
          case '/sem-link.html':
            req.response.headers.contentType = ContentType.html;
            req.response.write('<div class="post-body">nada aqui</div>');
          default:
            req.response.statusCode = 404;
        }
        await req.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('PDF direto e com redirecionamento', () async {
      final d = SourceDownloader();
      final dest = '${dir.path}/a.pdf';
      expect(await d.download('$base/redir', dest), '$base/redir');
      final bytes = await File(dest).readAsBytes();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, fakePdf().length);
      d.close();
    });

    test('página HTML: encontra o link e ignora o quebrado', () async {
      final d = SourceDownloader();
      final dest = '${dir.path}/b.pdf';
      final from = await d.download('$base/pagina.html', dest);
      expect(from, '$base/arquivo/hinario.pdf');
      expect(await File(dest).exists(), isTrue);
      d.close();
    });

    test('página sem link gera erro claro', () async {
      final d = SourceDownloader();
      await expectLater(d.download('$base/sem-link.html', '${dir.path}/c.pdf'),
          throwsA(isA<DownloadFailure>()));
      d.close();
    });
  });
}
