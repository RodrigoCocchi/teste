import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/libras_page.dart';
import '../data/libras_phrases.dart';
import '../theme.dart';

/// Tradutor de Libras com o avatar do VLibras (governo federal, gratuito).
/// O texto é digitado no app e enviado ao avatar com um toque.
class LibrasScreen extends StatefulWidget {
  const LibrasScreen({super.key});
  @override
  State<LibrasScreen> createState() => _LibrasScreenState();
}

class _LibrasScreenState extends State<LibrasScreen> {
  late final WebViewController _web;
  final _text = TextEditingController();
  bool _loading = true;
  bool _failed = false;
  String _category = librasPhrases.keys.first;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
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

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _web.loadHtmlString(librasHtml, baseUrl: 'https://bibliahinos.local/libras');
  }

  void _show(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    _web.runJavaScript('mostrar(${jsonEncode(t)})');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final hasText = _text.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libras'),
        actions: [IconButton(tooltip: 'Recarregar', onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_failed)
          MaterialBanner(
            content: const Text('Não foi possível carregar o VLibras. O tradutor precisa de internet.'),
            actions: [TextButton(onPressed: _load, child: const Text('Tentar de novo'))],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            controller: _text,
            textInputAction: TextInputAction.send,
            onSubmitted: _show,
            decoration: InputDecoration(
              hintText: 'Escreva uma palavra ou frase',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: hasText
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: _text.clear, tooltip: 'Limpar')
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.sign_language),
              label: const Text('Mostrar em Libras'),
              onPressed: hasText ? () => _show(_text.text) : null,
            ),
          ),
        ),
        // Frases prontas: escolhe o grupo e toca na frase.
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final c in librasPhrases.keys)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c),
                  selected: c == _category,
                  onSelected: (_) => setState(() => _category = c),
                ),
              ),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final f in librasPhrases[_category]!)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 18, color: AppColors.navy),
                  label: Text(f),
                  onPressed: () {
                    _text.text = f;
                    _show(f);
                  },
                ),
              ),
          ]),
        ),
        const Divider(height: 8),
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
