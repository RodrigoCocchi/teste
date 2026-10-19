"""Diagnóstico da página de relatório da CCB: estrutura, formulários e
endereços de dados usados pela página (não salva conteúdo)."""
import json, re, sys, urllib.request, urllib.parse

UA = {"User-Agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36"}
BASE = "https://congregacaocristanobrasil.org.br"

def get(url, data=None, headers=None):
    h = dict(UA); h.update(headers or {})
    req = urllib.request.Request(url, data=data, headers=h)
    with urllib.request.urlopen(req, timeout=40) as r:
        return r.status, r.headers.get("content-type", ""), r.read()

def show(url):
    try:
        st, ct, body = get(url)
    except Exception as e:
        print(f"[probe] {url} -> ERRO {e}"); return None
    print(f"[probe] {url} -> {st} {ct} {len(body)} bytes")
    return body.decode("utf-8", "replace")

html = show(BASE + "/relatorio")
if html:
    print("[probe] title:", re.findall(r"<title>(.*?)</title>", html, re.S)[:1])
    for m in re.finditer(r"<form[^>]*>", html): print("[probe] form:", m.group(0)[:300])
    for m in re.finditer(r"<(input|select)[^>]*>", html): print("[probe] campo:", m.group(0)[:200])
    for m in re.finditer(r"<option[^>]*value=\"([^\"]*)\"[^>]*>([^<]{0,40})", html):
        pass
    opts = re.findall(r"<option[^>]*value=\"([^\"]*)\"[^>]*>([^<]{0,40})", html)
    print("[probe] options (primeiras 30):", opts[:30], "total", len(opts))
    scripts = re.findall(r"<script[^>]*src=\"([^\"]+)\"", html)
    print("[probe] scripts:", scripts)
    for pat in [r"https?://[^\"' <>]*api[^\"' <>]*", r"/api/[^\"' <>]*", r"[\"'](/[^\"']*relatorio[^\"']*)[\"']",
                r"ajax[^\n]{0,200}", r"fetch\([^\n]{0,200}", r"lat[a-z]*[\"']?\s*[:=][^\n]{0,80}"]:
        found = sorted(set(re.findall(pat, html, re.I)))[:20]
        if found: print(f"[probe] padrão {pat}:", found)
    # trechos de texto visíveis (estrutura)
    text = re.sub(r"<script.*?</script>|<style.*?</style>", " ", html, flags=re.S)
    text = re.sub(r"<[^>]+>", "\n", text)
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    print("[probe] linhas de texto:", len(lines))
    for l in lines[:120]: print("[probe] |", l[:160])
    # scripts do próprio site: procurar endpoints
    for s in scripts:
        u = urllib.parse.urljoin(BASE + "/relatorio", s)
        if "congregacaocristanobrasil" not in u: continue
        js = show(u)
        if not js: continue
        for pat in [r"[\"'](/[A-Za-z0-9_/\-\.]*(?:api|relatorio|igreja|localidade|cidade|culto|busca)[A-Za-z0-9_/\-\.?=&]*)[\"']",
                    r"https?://[A-Za-z0-9\.\-]+/[A-Za-z0-9_/\-\.]*(?:api|relatorio)[A-Za-z0-9_/\-\.?=&]*",
                    r"(?:url|action)\s*:\s*[\"'][^\"']+[\"']"]:
            found = sorted(set(re.findall(pat, js, re.I)))[:25]
            if found: print(f"[probe] {s} {pat}:", found)

# Página inicial: links de cada seção (Culto on-line, Pedir oração, etc.)
home = show(BASE + "/")
if home:
    for m in re.finditer(r"<a[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>", home, re.S):
        label = re.sub(r"<[^>]+>", " ", m.group(2))
        label = re.sub(r"\s+", " ", label).strip()
        alt = re.findall(r"(?:alt|title|aria-label)=\"([^\"]+)\"", m.group(0))
        print("[link]", m.group(1), "|", label[:80], "|", alt[:2])
