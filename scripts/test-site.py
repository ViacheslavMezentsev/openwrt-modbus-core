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
expected=source.read_text().replace('на роутере','в демо').replace('на роутер','в демо').replace('с роутера','из браузера').replace('с роутером','с локальной моделью').replace('Проверьте вход в LuCI, сеть','Проверьте файл').replace('вход LuCI','демо')
assert (out/'schoolbell/assets/schedules.js').read_text()==expected
subprocess.run(['node',str(root/'scripts/test-schoolbell-routes.js')],cwd=root,env=dict(os.environ,SCHOOLBELL_UI_DIR=str(out/'schoolbell/assets')),check=True)
print('PASS Pages shares editor/reconciliation and runs the same no-hardware journey regressions')
