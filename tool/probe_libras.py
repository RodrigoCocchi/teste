"""Verifica se o VLibras traduz com clique feito por JavaScript (um botão só)."""
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
        await page.goto(f"http://127.0.0.1:8765/{PAGE}")
        await page.wait_for_timeout(15000)
        def gloss(since): return [u.rsplit('/', 1)[-1] for u in reqs[since:] if "WEBGL/" in u or "translate" in u]
        tests = [
            ("el.click()", "var a=document.getElementById('alvo');a.textContent='A paz de Deus';a.style.display='block';a.click();"),
            ("dispatch mouse", "var a=document.getElementById('alvo');a.textContent='Vai com Deus';a.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,view:window}));"),
            ("pointer+mouse", "var a=document.getElementById('alvo');a.textContent='Jesus';for (const t of ['pointerdown','mousedown','pointerup','mouseup','click']) a.dispatchEvent(new (t.startsWith('pointer')?PointerEvent:MouseEvent)(t,{bubbles:true,cancelable:true,view:window}));"),
        ]
        for name, js in tests:
            n = len(reqs)
            await page.evaluate(js)
            await page.wait_for_timeout(9000)
            print("[l]", name, "->", gloss(n))
        print("[l] globals:", await page.evaluate("Object.keys(window).filter(k=>/vlibras|plugin/i.test(k))"))
        await b.close()

asyncio.run(main())
