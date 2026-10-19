import 'dart:convert';

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
