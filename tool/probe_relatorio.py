"""Diagnóstico dos serviços de pesquisa do relatório da CCB: mostra como a
página chama os serviços e a estrutura das respostas (só chaves e amostras)."""
import json, re, urllib.request, urllib.parse, http.cookiejar

JAR = http.cookiejar.CookieJar()
OPENER = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(JAR))
UA = {"User-Agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36"}
BASE = "https://congregacaocristanobrasil.org.br"

def req(path, data=None, headers=None, method=None):
    h = dict(UA); h.update(headers or {})
    r = urllib.request.Request(BASE + path, data=data, headers=h, method=method)
    try:
        with OPENER.open(r, timeout=40) as resp:
            return resp.status, resp.headers.get("content-type", ""), resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("content-type", ""), e.read().decode("utf-8", "replace")

def shape(v, depth=0):
    if isinstance(v, list):
        return f"lista[{len(v)}] de " + (shape(v[0], depth + 1) if v else "?")
    if isinstance(v, dict):
        return "{" + ", ".join(f"{k}: {shape(x, depth + 1) if depth < 3 else type(x).__name__}" for k, x in list(v.items())[:30]) + "}"
    return f"{type(v).__name__}({str(v)[:40]!r})"

st, ct, html = req("/relatorio")
print("[p] relatorio", st, len(html))
token = re.search(r'name="__RequestVerificationToken" type="hidden" value="([^"]+)"', html)
token = token.group(1) if token else ""
for m in re.finditer(r"/service/[a-z\-]+", html):
    a = max(0, m.start() - 700); b = m.end() + 900
    print("[p] ===== trecho", m.group(0))
    for line in html[a:b].splitlines():
        if line.strip(): print("[p] |", line.rstrip()[:220])
print("[p] funções JS:", sorted(set(re.findall(r"function\s+(\w+)\s*\(", html))))

def tryall(path, payloads):
    for kind, data, hdr in payloads:
        st, ct, body = req(path, data=data, headers=hdr, method="POST" if data is not None else "GET")
        info = body[:300].replace("\n", " ")
        try:
            j = json.loads(body); info = shape(j)
        except Exception: pass
        print(f"[p] {path} {kind} -> {st} {ct[:30]} {info[:900]}")

hdr_form = {"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8", "X-Requested-With": "XMLHttpRequest",
            "RequestVerificationToken": token}
hdr_json = {"Content-Type": "application/json", "X-Requested-With": "XMLHttpRequest", "RequestVerificationToken": token}
enc = lambda d: urllib.parse.urlencode(dict(d, __RequestVerificationToken=token)).encode()
tryall("/service/pais-relatorio", [("GET", None, {"X-Requested-With": "XMLHttpRequest"}), ("POST", enc({}), hdr_form)])
tryall("/service/estado-relatorio", [("POST pais=1", enc({"pais": "1"}), hdr_form), ("POST id=1", enc({"id": "1"}), hdr_form)])
tryall("/service/localidade-relatorio", [("POST busca", enc({"busca": "Bras"}), hdr_form),
                                        ("JSON busca", json.dumps({"busca": "Bras"}).encode(), hdr_json)])
