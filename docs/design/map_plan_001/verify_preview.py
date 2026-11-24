from pathlib import Path
import json,threading,http.server,functools
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;QA=ROOT/'.local_validation/MAP_PLAN_001';QA.mkdir(parents=True,exist_ok=True)
handler=functools.partial(http.server.SimpleHTTPRequestHandler,directory=str(OUT))
server=http.server.ThreadingHTTPServer(('127.0.0.1',8794),handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
url='http://127.0.0.1:8794/'
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
 page=browser.new_page(viewport={'width':2160,'height':1365},device_scale_factor=1)
 errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto(url+'layout.svg');page.evaluate('document.fonts.ready');page.screenshot(path=str(OUT/'layout.png'))
 page.set_viewport_size({'width':1600,'height':1024});page.goto(url+'blockout.svg');page.screenshot(path=str(OUT/'blockout.png'))
 page.set_viewport_size({'width':1600,'height':1100});page.goto(url+'preview.html');page.evaluate('document.fonts.ready')
 assert page.locator('svg [data-item^="prop:"]').count()==32
 assert page.locator('svg [data-item^="solid:"]').count()==20
 page.locator('[data-pick="B"]').click();assert '불탄 병참 구역' in page.locator('#info').inner_text()
 page.locator('#overview').click();page.locator('svg [data-item="solid:B1"]').click();assert '불탄 병참창고' in page.locator('#info').inner_text()
 page.locator('[data-layer="original"]').check();assert page.locator('.layer-original').evaluate('(e)=>getComputedStyle(e).display')!='none'
 page.locator('[data-layer="props"]').uncheck();assert page.locator('.layer-props').evaluate('(e)=>getComputedStyle(e).display')=='none'
 page.locator('[data-layer="props"]').check();page.locator('[data-layer="original"]').uncheck()
 page.locator('#phase').select_option('0');assert page.locator('svg [data-at="120"]').evaluate('(e)=>getComputedStyle(e).display')=='none'
 page.locator('#phase').select_option('240');page.locator('#zoom-in').click();assert float(page.locator('#stage>svg').get_attribute('viewBox').split()[2])<5000
 page.locator('#zoom-out').click();page.locator('#reset').click();assert page.locator('#stage>svg').get_attribute('viewBox')=='0 0 5000 3200'
 with page.expect_download() as pending:page.locator('#json').click()
 download=pending.value;download.save_as(str(QA/'downloaded-layout.json'))
 assert json.loads((QA/'downloaded-layout.json').read_text())['destructibles']==json.loads((OUT/'layout.json').read_text())['destructibles']
 page.screenshot(path=str(QA/'desktop.png'),full_page=True)
 page.set_viewport_size({'width':390,'height':844});page.reload();assert page.evaluate('document.documentElement.scrollWidth')<=390
 page.locator('#zoom-in').click();page.locator('#reset').click();page.screenshot(path=str(QA/'mobile.png'),full_page=True)
 assert not errors,errors
 result={'status':'PASS','tested_date_kst':'2026-11-24','scope':'SVG/HTML export and actual headless Chromium interactions;not game-engine/mobile gameplay approval.','props':32,'solids':20,'checks':['Korean font export','district/building selection','original/proposed toggles','phase visibility','zoom/reset','JSON download','390px responsive layout','no browser script errors'],'errors':errors}
 (OUT/'browser-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');(QA/'browser-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False));browser.close()

server.shutdown()
