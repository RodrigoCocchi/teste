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
m = re.search(r'name="__RequestVerificationToken" type="hidden" value="([^"]+)"', html)
token = m.group(1) if m else ""
H = {"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8", "X-Requested-With": "XMLHttpRequest",
     "AntiForgeryToken": token}

def post(path, d):
    st, ct, body = req(path, data=urllib.parse.urlencode(d).encode(), headers=H, method="POST")
    print(f"[p] {path} {d} -> {st} {ct[:30]} len={len(body)}")
    try:
        return json.loads(body)
    except Exception:
        return body

def dump(body, n=6000):
    text = body if isinstance(body, str) else json.dumps(body, ensure_ascii=False)
    for line in text[:n].splitlines():
        if line.strip(): print("[p] |", line.rstrip()[:240])

def pick(lst, words):
    items = lst.get("list", lst) if isinstance(lst, dict) else []
    for it in items:
        if any(w.lower() in str(it.get("Text", "")).lower() for w in words): return it
    return items[1] if len(items) > 1 else None

for m in re.finditer(r'<input[^>]*type="checkbox"[^>]*>', html):
    print("[p] chk", m.group(0)[:200])
for m in re.finditer(r'<label[^>]*for="[^"]*"[^>]*>[^<]{1,60}</label>', html):
    print("[p] lbl", m.group(0)[:160])
city = None
import sys
for pag in ["1", "2"]:
    r = post("/service/servico-relatorio", {"codigoPais": "1", "codigoEstado": "376", "codigoCidade": "2329",
             "tipoCulto": "Culto Oficial,Reunião de Jovens e Menores", "diaSemana": "1,2,3,4,5,6,7",
             "periodo": "Manhã,Tarde,Noite", "pagina": pag})
    print("[p] rows", r.count("data-id") if isinstance(r, str) else r, re.findall(r"Exibindo[^<]*", str(r)))
sys.exit(0)
# Trechos JS que montam os parâmetros
for m in re.finditer(r"/service/(estado|cidade|servico|localidade)[a-z\-]*", html):
    a = max(0, m.start() - 300); b = m.end() + 500
    print("[p] ===== trecho", m.group(0)); dump(html[a:b], 900)

pais = post("/service/pais-relatorio", {})
br = pick(pais, ["brasil"]); print("[p] pais", br)
est = None
for key in ["codigoPais", "pais", "id", "codigo"]:
    r = post("/service/estado-relatorio", {key: br["Value"]})
    if isinstance(r, dict) and len(r.get("list", [])) > 1:
        est = r; print("[p] estado param =", key); break
sp = pick(est or {}, ["são paulo", "sao paulo", "SP"]); print("[p] estado", sp)
cid = None
for key in ["codigoEstado", "estado", "id", "codigo"]:
    r = post("/service/cidade-relatorio", {key: sp["Value"]} if sp else {})
    if isinstance(r, dict) and len(r.get("list", [])) > 1:
        cid = r; print("[p] cidade param =", key); dump(r, 600); break
city = pick(cid or {}, ["campinas"]); print("[p] cidade", city)
serv = post("/service/servico-relatorio", {"codigoPais": br["Value"], "codigoEstado": sp["Value"] if sp else "",
            "codigoCidade": city["Value"] if city else "", "tipoCulto": "Culto Oficial", "diaSemana": "1",
            "periodo": "Noite", "pagina": "1"})
print("[p] ===== servico"); dump(serv)
loc = post("/service/localidade-relatorio", {"search": "Bras", "pagina": "1"})
print("[p] ===== localidade"); dump(loc)
ids = re.findall(r'data-id="([^"]+)"', loc if isinstance(loc, str) else "") + \
      re.findall(r'data-id="([^"]+)"', serv if isinstance(serv, str) else "")
print("[p] ids", ids[:10])
if ids:
    det = post("/service/localidade-detalhe", {"codigo": ids[0]})
    print("[p] ===== detalhe"); dump(det, 8000)
    for k in ["latitude", "longitude", "lat", "lng", "maps", "endere", "cep"]:
        print("[p] contem", k, k in str(det).lower())
