#!/usr/bin/env python3
"""Static GitHub Pages, sharing the router UI sources; no network or device calls."""
from pathlib import Path
import html, re, shutil, sys, subprocess, datetime, json
root=Path(__file__).resolve().parent.parent
out=Path(sys.argv[1]) if len(sys.argv)>1 else root/'out/site'
out.mkdir(parents=True,exist_ok=True)
try:
 commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
 dirty=bool(subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip())
except (OSError,subprocess.CalledProcessError):
 commit='unknown';dirty=True
built=datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds').replace('+00:00','Z')
metadata={'built_at_utc':built,'commit':commit,'dirty':dirty}
(out/'build-info.json').write_text(json.dumps(metadata,indent=2)+'\n')
label='Сборка: '+built+' · commit '+commit[:12]+(' · локальные изменения' if dirty else '')
provenance='<p class="build-info">'+html.escape(label)+'</p>'
version=re.search(r'^Version: (.+)$',(root/'pkg-schoolbell/CONTROL/control').read_text(),re.M)[1]
source=root/'packages/schoolbell/router-page/root'
for name in ['index.html','index.en.html']:
 text=(root/'site'/name).read_text().replace('{{VERSION}}',html.escape(version)).replace('{{DAYS}}',''.join('<span>'+str(i)+'</span>' for i in range(1,22)))
 footer=provenance if name=='index.html' else provenance.replace('Сборка:', 'Build:').replace('локальные изменения','local changes')
 (out/name).write_text(text.replace('</footer>',footer+'</footer>'))
shutil.copyfile(root/'site/style.css',out/'style.css')
shutil.copyfile(source/'www/schoolbell-test/theme.js',out/'theme.js')
(out/'.nojekyll').write_text('')
demo=out/'schoolbell';assets=demo/'assets';assets.mkdir(parents=True,exist_ok=True)
for p in (source/'www/schoolbell-test').iterdir():
 text=p.read_text()
 if p.suffix=='.js':
  text=text.replace('на устройстве','в демо').replace('на роутере','в демо').replace('на роутер','в демо').replace('с роутера','из браузера').replace('с роутером','с локальной моделью').replace('Проверьте вход в LuCI, сеть','Проверьте файл').replace('вход LuCI','демо')
 (assets/p.name).write_text(text)
shutil.copyfile(root/'site/demo.js',assets/'demo.js')
for name in ['test','0','1','2','3','4']:
 shutil.copyfile(root/('packages/schoolbell/media/'+name+'.mp3'),assets/(name+'.mp3'))
shutil.copyfile(root/'pkg-schoolbell/usr/share/modbus-schoolbell/NOTICE',assets/'NOTICE.txt')
text=(source/'usr/lib/lua/luci/view/schoolbell_test.htm').read_text()
values={'session_url':'./demo-api/session','login_url':'./','auth_user':'Демо без входа','trust_url':'./demo-api/clock-trust','backup_url':'./demo-api/backup','media_url':'./demo-api/media','automatic_url':'./demo-api/automatic','controls_url':'./demo-api/controls','manual_url':'./demo-api/no-router','preview_url':'./demo-api/preview','schedules_url':'./demo-api/load','save_url':'./demo-api/save','clock_url':'./demo-api/clock','journal_url':'./demo-api/journal','timezone_url':'./demo-api/timezone','sample_url':'./assets/test.mp3','play_url':'./demo-api/no-router','module_version':version+' · DEMO','core_version':'не подключено','token':'demo'}
for key,value in values.items():text=text.replace('<%=pcdata('+key+')%>',html.escape(value,quote=True))
text=text.replace("<%=url('admin')%>",'../').replace('← Управление роутером LuCI','← О проекте')
text=text.replace('/schoolbell-test/','./assets/')
text=text.replace('Сверить с роутером','Сверить с локальной моделью').replace('Копия роутера','Сохранённая копия демо').replace('Взять копию роутера','Взять сохранённую копию демо')
text=text.replace('<p class="intro">','<aside class="notice"><strong>ДЕМО · оборудование не подключено.</strong> Календарные планы можно редактировать без устройства. Расписания и часовой пояс изменяются только в этом браузере. Автозвонков нет. <span id="demo-storage">Данные демо сохраняются локально.</span> <button id="demo-reset" type="button">Сбросить демо</button></aside><p class="intro">',1)
text=text.replace('Сохранить черновик на устройстве','Сохранить черновик в демо')
text=text.replace('Подготовьте расписания и сохраните их на роутере.','Попробуйте расписания и календарь на тестовых данных.')
text=text.replace('Инженерная установка','Демонстрация интерфейса').replace('На роутере · оценка между опросами','Демо-часы · выбранная зона').replace('Сохраняется на роутере','Сохраняется в браузере').replace('Настройка сохраняется на роутере и действует для всех его приложений.','Настройка меняет только часовой пояс этого демо, не устройства или компьютера.')
text=text.replace('id="router-play" type="submit"','id="router-play" type="submit" disabled').replace('▶ Позвонить на роутере','Недоступно в демо · нет роутера').replace('Колонки должны быть включены и подключены к аудиовыходу.','В демо нет подключения к роутеру. Доступен только звук браузера.')
text=re.sub(r'(?=<script src="\./assets/clock-trust\.js(?:\?[^"]*)?">)', '<script src="./assets/ranges.js"></script><script src="./assets/demo.js"></script>', text, count=1)
assert '<%=' not in text,'unresolved template'
text=text.replace('</footer>',provenance+'</footer>')
(demo/'index.html').write_text(text)
print('Built static site:',out)

# Retain old incoming links without maintaining a second calendar editor.
(demo/'ranges.html').write_text('<!doctype html><html lang="ru"><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=./"><title>Календарные планы</title><a href="./">Открыть рабочий редактор календарных планов</a></html>')
