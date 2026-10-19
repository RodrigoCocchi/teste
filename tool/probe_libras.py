"""Abre a página do tradutor de Libras no Chromium e verifica se o VLibras carrega e traduz."""
import asyncio, http.server, threading, functools, sys
from playwright.async_api import async_playwright

PAGE = sys.argv[1]

def serve():
    h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=".")
    http.server.ThreadingHTTPServer(("127.0.0.1", 8765), h).serve_forever()

async def main():
    threading.Thread(target=serve, daemon=True).start()
    async with async_playwright() as p:
        b = await p.chromium.launch(args=["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"])
        page = await b.new_page(viewport={"width": 412, "height": 860}, is_mobile=True, has_touch=True)
        reqs = []
        page.on("request", lambda r: reqs.append(r.url))
        page.on("console", lambda m: print("[l] console", m.type, m.text[:200]))
        await page.goto(f"http://127.0.0.1:8765/{PAGE}")
        await page.wait_for_timeout(15000)
        print("[l] VLibras:", await page.evaluate("!!window.VLibras && !!window.VLibrasWidget"))
        print("[l] root:", await page.evaluate("(()=>{const r=document.getElementById('vlibras-app-root');return r?('active='+r.dataset.active):'sem root'})()"))
        await page.screenshot(path="libras.png")
        await page.evaluate("document.getElementById('texto').value='A paz de Deus'; preparar();")
        await page.wait_for_timeout(1500)
        print("[l] alvo visível:", await page.evaluate("getComputedStyle(document.getElementById('alvo')).display"))
        n = len(reqs)
        try:
            await page.locator("#alvo").tap(timeout=5000)
        except Exception as e:
            print("[l] tap falhou:", str(e)[:200])
            await page.locator("#alvo").click(force=True, timeout=5000)
        await page.wait_for_timeout(15000)
        print("[l] novas requisições após tocar:", [u[:140] for u in reqs[n:]][:30])
        try:
            await page.locator(".frase", has_text="Aleluia").click(force=True, timeout=5000)
            await page.wait_for_timeout(8000)
        except Exception as e:
            print("[l] frase falhou:", str(e)[:200])
        print("[l] requests vlibras:")
        for u in reqs:
            if "vlibras" in u or "traducao" in u: print("[l]   ", u[:160])
        print("[l] traduziu:", any("translate" in u or "traducao" in u for u in reqs))
        await page.screenshot(path="libras2.png")
        await b.close()

asyncio.run(main())
