#!/usr/bin/env python3
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit,unquote
import ast,hashlib,re,json,datetime,subprocess,os
root=Path(__file__).resolve().parent.parent
out=root/'out/site'
class Links(HTMLParser):
 def handle_starttag(self,tag,attrs):
  for key,value in attrs:
   if key not in ('href','src') or not value:continue
   u=urlsplit(value)
   if u.scheme or value.startswith('#'):continue
   p=(self.base/unquote(u.path)).resolve()
   if p.is_dir():p=p/'index.html'
   assert p.is_file(),str(p)
for p in out.rglob('*.html'):
 t=p.read_text();assert '<%=' not in t and '/cgi-bin/' not in t and '192.168.' not in t
 parser=Links();parser.base=p.parent;parser.feed(t)
source=root/'packages/schoolbell/router-page/root/www/schoolbell-test/schedules.js'
colors=ast.literal_eval(re.search(r'var colors=(\[[^;]+\]);',source.read_text())[1])
assert len(colors)==len(set(colors))==16
for color in colors:
 rgb=[int(color[i:i+2],16)/255 for i in (1,3,5)]
 assert all(round(x*255) in (0,95,135,175,215,255) for x in rgb)
 linear=[x/12.92 if x<=0.04045 else ((x+.055)/1.055)**2.4 for x in rgb]
 lum=sum(a*b for a,b in zip(linear,[.2126,.7152,.0722]))
 contrast=(lum+.05)/.05 if lum>.179 else 1.05/(lum+.05)
 assert contrast>=4.5,(color,contrast)
assert hashlib.sha256((out/'schoolbell/assets/test.mp3').read_bytes()).digest()==hashlib.sha256((root/'packages/schoolbell/media/test.mp3').read_bytes()).digest()
html=(out/'schoolbell/index.html').read_text();assert 'id="router-play" type="submit" disabled' in html and 'DEMO' in html
assert html.index('assets/demo.js')<html.index('assets/app.js')
assert not any(p.is_symlink() for p in out.rglob('*'))
print('PASS site: relative links, no router URLs, audio hash, disabled hardware action, 16 xterm colors with readable text')

info=json.loads((out/'build-info.json').read_text())
assert info['commit']==subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert info['dirty']==bool(subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip())
assert datetime.datetime.fromisoformat(info['built_at_utc'].replace('Z','+00:00')).utcoffset()==datetime.timedelta(0)
for name in ['index.html','index.en.html','schoolbell/index.html']:
 page=(out/name).read_text();assert info['built_at_utc'] in page and info['commit'][:12] in page,name
print('PASS build provenance: UTC timestamp, HEAD commit, dirty flag and visible footer')

for name in ["test","0","1","2","3","4"]:
 assert (out/("schoolbell/assets/"+name+".mp3")).read_bytes()==(root/("packages/schoolbell/media/"+name+".mp3")).read_bytes()

for element in ['draft-compare','draft-comparison','draft-local-json','draft-router-json','draft-keep-local','draft-use-router']:
 assert 'id="'+element+'"' in html,element
assert 'Сверить с локальной моделью' in html
expected=source.read_text().replace('на устройстве','в демо').replace('на устройство','в демо').replace('с устройства','из браузера').replace('с устройством','с локальной моделью').replace('на роутере','в демо').replace('на роутер','в демо').replace('с роутера','из браузера').replace('с роутером','с локальной моделью').replace('Проверьте вход в LuCI, сеть','Проверьте файл').replace('вход LuCI','демо')
expected=expected.replace('window.schoolbellEditor={','window.schoolbellEditor={portableSnapshot:function(){return {draft:draft?JSON.parse(JSON.stringify(draft)):null,dirty:dirty||formPending,formPending:formPending,busy:busy||activationLock,reconcile:reconcile,revision:revision};},',1)
assert (out/'schoolbell/assets/schedules.js').read_text()==expected
subprocess.run(['node',str(root/'scripts/test-schoolbell-routes.js')],cwd=root,env=dict(os.environ,SCHOOLBELL_PAGES_TEST='1',SCHOOLBELL_UI_DIR=str(out/'schoolbell/assets')),check=True)
print('PASS Pages shares editor/reconciliation and runs the same no-hardware journey regressions')

# Quick reference is shared with the target template, with no action controls.
assert html.index('id="tab-help"') < html.index('id="tab-calendar"')
assert 'Шпаргалка' in html
help_panel=html.split('id="panel-help"',1)[1].split('</section>',1)[0]
assert '<button' not in help_panel and '<input' not in help_panel and '<form' not in help_panel
assert 'aria-labelledby="tab-help"' in help_panel
assert 'Сверить с локальной моделью' in help_panel
print('PASS first shared quick reference tab; no action controls')

assert 'id="guide-important"' in html
assert '<div class="guide-route">' in html
assert 'guide-route:nth-child(even)' in (out/'schoolbell/assets/style.css').read_text()
assert 'id="session-countdown"' in html and 'id="session-duration"' in html
assert 'data-session="./demo-api/session"' in html
assert html.index('assets/session.js') < html.index('assets/backup.js')
print('PASS shared striped guide, separate behavior notes and demo-safe session panel')

assert (out/'schoolbell/ranges.html').exists()
range_html=(out/'schoolbell/ranges.html').read_text()
assert 'Открыть рабочий редактор' in range_html
assert 'Календарные планы' in html and 'id="plan-start"' in html and 'id="plan-end"' in html
assert 'id="session-countdown" hidden' in html and 'role="timer"' not in html
assert 'target="_blank"' not in html.split('id="session-login"',1)[1].split('>',1)[0]
print('PASS separate range prototype; compact same-tab login with no visible countdown')

assert "<h1>Школьник</h1>" in (out/"schoolbell/index.html").read_text()
assert "<title>Школьник · расписания</title>" in (out/"schoolbell/index.html").read_text()

calendar_html=(out/'schoolbell/index.html').read_text()
assert calendar_html.index('id="plan-status"') < calendar_html.index('id="months-navigation"') < calendar_html.index('id="year-grid"') < calendar_html.index('id="months-bottom-navigation"')

assert 'Сохранить черновик в демо' in calendar_html
assert 'Сохранить черновик на устройстве' not in calendar_html

# Portable codecs are copied byte-for-byte, not forked or added to the IPK.
for name in ['codec','export','preview']:
 assert (out/('schoolbell/assets/portable-'+name+'.js')).read_bytes()==(root/('packages/schoolbell/portable-plan/'+name+'.js')).read_bytes()
assert 'portableSnapshot' not in source.read_text()
assert 'portable-panel' not in (root/'packages/schoolbell/router-page/root/usr/lib/lua/luci/view/schoolbell_test.htm').read_text()
assert html.index('assets/schedules.js')<html.index('assets/portable-ui.js')
assert 'импорт только проверяется' in html

assert 'Настраиваемый музыкальный звонок' in html
assert 'id="device-uptime"' in html and 'class="cpu-labels"' in html

# Pages guide is standalone and never enters the device payload.
import xml.etree.ElementTree as ET
for lang,name in [('ru','guide.html'),('en','guide.en.html')]:
 page=(out/'schoolbell'/name).read_text()
 assert '{{' not in page and page.count('<svg ')==2
 assert 'href="./"' in page and 'theme-toggle' in page
 assert info['commit'][:12] in page and info['built_at_utc'] in page
 assert 'demo.js' not in page and 'fetch(' not in page
 for diagram in ['bench','audio']:ET.parse(root/'site/diagrams'/(diagram+'.'+lang+'.svg'))
assert 'class="demo-guide" href="./guide.html"' in html
assert 'schoolbell/guide.html' in (out/'index.html').read_text()
assert 'schoolbell/guide.en.html' in (out/'index.en.html').read_text()
assert 'demo-guide' not in (root/'packages/schoolbell/router-page/root/usr/lib/lua/luci/view/schoolbell_test.htm').read_text()
print('PASS guide: RU/EN routes, return links, SVG, provenance and Pages-only boundary')

notice=html.split('id="demo-notice"',1)[1].split('</details>',1)[0]
assert 'demo-guide' not in notice
assert '</details><a class="demo-guide" href="./guide.html">Руководство</a></div>' in html
feedback=html.split('id="panel-feedback"',1)[1].split('</section>',1)[0]
assert 'id="feedback-build"' in feedback and info['commit'] in feedback and info['built_at_utc'] in feedback
assert ('Собрано с локальными изменениями.' in feedback)==info['dirty']
print('PASS standalone guide button and exact build provenance beside feedback authors')
