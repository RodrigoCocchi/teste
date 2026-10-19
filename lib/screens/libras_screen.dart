import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/libras_page.dart';
import '../data/libras_phrases.dart';

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
