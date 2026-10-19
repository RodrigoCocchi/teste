import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/libras_phrases.dart';

/// Página carregada no WebView: o widget oficial do VLibras (avatar 3D) traduz
/// o texto que a pessoa toca. As frases prontas e o texto digitado viram
/// elementos de texto tocáveis.
String librasHtml(Map<String, List<String>> phrases) => '''
<!doctype html>
<html lang="pt-BR"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font-family: sans-serif; margin: 0; padding: 12px 12px 90px; background: #f7f2e7; color: #1c2541; }
  h2 { font-size: 15px; margin: 18px 0 6px; color: #0b2545; }
  .dica { font-size: 13px; color: #555; margin: 4px 0 10px; }
  textarea { width: 100%; box-sizing: border-box; font-size: 17px; padding: 10px; border-radius: 10px;
             border: 1px solid #b9a777; min-height: 70px; }
  .btn { display: inline-block; margin-top: 8px; padding: 10px 16px; border-radius: 22px; background: #0b2545;
         color: #fff; font-size: 16px; border: none; }
  .alvo { font-size: 22px; font-weight: bold; padding: 14px; margin: 10px 0; border-radius: 12px; background: #e3ecff;
          border: 2px solid #1351b4; color: #1351b4; display: none; }
  .frases { display: flex; flex-wrap: wrap; gap: 8px; }
  .frase { margin: 0; padding: 10px 14px; border-radius: 20px; background: #fff; border: 1px solid #c9b98f;
           font-size: 16px; color: #0b2545; }
  .frase:active, .alvo:active { background: #d4af37; }
</style>
</head><body>
<p class="dica">Escreva uma palavra ou frase, toque em <b>Preparar</b> e depois toque no texto em azul
para o avatar mostrar em Libras. As frases prontas também podem ser tocadas.</p>
<textarea id="texto" placeholder="Ex.: A paz de Deus"></textarea>
<button class="btn" type="button" onclick="preparar()">Preparar</button>
<p id="alvo" class="alvo"></p>
${phrases.entries.map((e) => '<h2>${const HtmlEscape().convert(e.key)}</h2><div class="frases">${e.value.map((f) => '<p class="frase">${const HtmlEscape().convert(f)}</p>').join()}</div>').join('\n')}
<script>
  function abrir() { try { window.VLibrasWidget && window.VLibrasWidget.open && window.VLibrasWidget.open(); } catch (e) {} }
  function preparar() {
    var t = document.getElementById('texto').value.trim();
    var alvo = document.getElementById('alvo');
    if (!t) return;
    alvo.textContent = t;
    alvo.style.display = 'block';
    document.getElementById('texto').blur();
    abrir();
    alvo.scrollIntoView({behavior: 'smooth', block: 'center'});
  }
  function falhou() { if (window.Status) Status.postMessage('erro'); }
</script>
<script src="https://vlibras.gov.br/app/vlibras-plugin.js" onerror="falhou()"></script>
<script>
  try {
    new window.VLibras.Widget('https://vlibras.gov.br/app');
    setTimeout(abrir, 800);
    if (window.Status) Status.postMessage('ok');
  } catch (e) { falhou(); }
</script>
</body></html>
''';

/// Tradutor de Libras com o avatar do VLibras (governo federal, gratuito).
class LibrasScreen extends StatefulWidget {
  const LibrasScreen({super.key});
  @override
  State<LibrasScreen> createState() => _LibrasScreenState();
}

class _LibrasScreenState extends State<LibrasScreen> {
  late final WebViewController _web;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF7F2E7))
      ..addJavaScriptChannel('Status', onMessageReceived: (m) {
        if (mounted) setState(() => _failed = m.message == 'erro');
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? false) && mounted) setState(() => _failed = true);
        },
        onNavigationRequest: (r) {
          // Links externos (ex.: "Sobre o VLibras") abrem no navegador.
          if (r.url.startsWith('http') && !r.url.contains('vlibras.gov.br') && r.isMainFrame) {
            launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
    _load();
  }

  void _load() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _web.loadHtmlString(librasHtml(librasPhrases), baseUrl: 'https://bibliahinos.local/libras');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libras'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_failed)
          MaterialBanner(
            content: const Text('Não foi possível carregar o VLibras. O tradutor precisa de internet.'),
            actions: [TextButton(onPressed: _load, child: const Text('Tentar de novo'))],
          ),
        Expanded(child: WebViewWidget(controller: _web)),
        Container(
          width: double.infinity,
          color: t.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Text(
            'Tradução automática do VLibras (governo federal). Palavras que ele não conhece são soletradas, '
            'e os sinais usados na sua comunidade podem ser diferentes: confirme com os intérpretes da CCB.',
            style: t.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}
