"""Diagnóstico: como o plugin do VLibras expõe a tradução de texto."""
import re, urllib.request

UA = {"User-Agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36"}

def get(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except Exception as e:
        return str(e), ""

for url in ["https://vlibras.gov.br/app/vlibras-plugin.js", "https://vlibras.gov.br/app/"]:
    st, body = get(url)
    print("[v]", url, st, len(body))
    if not body: continue
    for kw in ["translate(", "window.plugin", "VLibras.Widget", "rootPath", "player.on(", "gloss", "setSpeed",
               "personalization", "opacity", "avatar", "targetPath", "Unity", "loadPlayer", "translator", ".play("]:
        hits = [m.start() for m in re.finditer(re.escape(kw), body)][:4]
        for h in hits:
            print(f"[v] {kw!r} @{h}: {body[max(0,h-220):h+260]!r}")
for m in re.finditer(r'https?://[a-zA-Z0-9./_-]+', get("https://vlibras.gov.br/app/vlibras-plugin.js")[1]):
    pass
urls = sorted(set(re.findall(r'https?://[a-zA-Z0-9./_-]+', get("https://vlibras.gov.br/app/vlibras-plugin.js")[1])))
print("[v] urls", urls[:60])
