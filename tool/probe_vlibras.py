"""Diagnóstico: como o plugin do VLibras expõe a tradução de texto."""
import re, urllib.request

UA = {"User-Agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36"}
ROOT = "https://vlibras.gov.br/app"

def get(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except Exception as e:
        return str(e), ""

st, loader = get(ROOT + "/vlibras-plugin.js")
print("[v] loader", st)
for i in range(0, len(loader), 400):
    print("[v] L|", loader[i:i+400])
paths = sorted(set(re.findall(r'\$\{r\}(/[A-Za-z0-9_./-]+)', loader)))
print("[v] paths", paths)
for p in paths:
    if not p.endswith((".js", ".html")): continue
    st, body = get(ROOT + p)
    print("[v] ==", p, st, len(body))
    for kw in ["translate", "postMessage", "addEventListener(`message`", "addEventListener(\"message\"", "window.plugin",
               "setSpeed", "speed", "gloss", "dictionary", "player", "text"]:
        for m in list(re.finditer(re.escape(kw), body))[:3]:
            h = m.start()
            print(f"[v] {p} {kw!r} @{h}: {body[max(0,h-200):h+250]!r}")
