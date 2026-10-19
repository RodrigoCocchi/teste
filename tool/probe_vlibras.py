"""Diagnóstico: API do app do VLibras (vlibras-plugin-app.js)."""
import re, urllib.request

UA = {"User-Agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36"}
ROOT = "https://vlibras.gov.br/app"

def get(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except Exception as e:
        return str(e), ""

seen = set()
def scan(path, depth=0):
    if path in seen or depth > 2: return
    seen.add(path)
    st, body = get(ROOT + "/" + path.lstrip("./"))
    print("[v] ==", path, st, len(body))
    if not body: return
    if len(body) < 3000:
        print("[v] BODY", body)
    for kw in ["translate", "window.plugin", "window.VLibras", "VLibrasWidget.", "getSelection", "click`", "`click",
               "speed", "gloss", "postMessage", "dispatchEvent", "CustomEvent", "translator", "api/", "https://"]:
        for m in list(re.finditer(re.escape(kw), body))[:4]:
            h = m.start()
            print(f"[v] {path} {kw!r} @{h}: {body[max(0,h-160):h+200]!r}")
    for imp in sorted(set(re.findall(r'''(?:import\(|from\s*|import\s*)["'`](\.{0,2}/?[A-Za-z0-9_./-]+\.js)''', body)))[:15]:
        scan(imp if not imp.startswith("./") else "assets/" + imp[2:] if path.startswith("assets/") else imp[2:], depth + 1)

scan("vlibras-plugin-app.js?v=7.12.2")
