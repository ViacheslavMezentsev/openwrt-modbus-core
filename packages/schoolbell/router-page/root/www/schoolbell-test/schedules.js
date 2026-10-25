(function () {
  'use strict';
  var root=document.getElementById('schedule-editor');
  var fields=document.getElementById('schedule-fields');
  var select=document.getElementById('schedule-select');
  var result=document.getElementById('schedule-result');
  var save=document.getElementById('schedule-save');
  var reload=document.getElementById('schedule-reload');
  var badge=document.getElementById('draft-state');
  var name=document.getElementById('schedule-name');
  var rows=document.getElementById('schedule-rows');
  var draft=null, revision=null, selected=null, dirty=false, busy=false, reconcile=false, activationLock=false;
  var compared=null, handoffReady=false;
  var handoffKey="schoolbell-editor-handoff-v1";
  var mediaNames={test:'Тестовый звонок','0':'[Короткая] Время','1':'Шутка Баха','2':'Гостья из XXI','3':'Князь Игорь','4':'Усатый нянь'};
  function mediaLabel(id){return (mediaNames[id] || ('Пользовательская '+id.slice(4)))+' · '+id;}
  window.addEventListener('schoolbell-media',function(e){e.detail.forEach(function(v){mediaNames[v.id]=(v.title || v.name)+(v.source==='empty'?' · пустой слот':'');});document.querySelectorAll('#manual-media option,#pre-media option,#schedule-rows select option').forEach(function(o){o.textContent=mediaLabel(o.value);});});
  var mediaIds=["test","0","1","2","3","4","user1","user2","user3","user4","user5","user6","user7","user8"];
  var counter=0;
  var year=new Date().getFullYear(), brush='view', painting=false;
  var monthNames=['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'];
  // Stable IDs; 5.0.2 replaces low-contrast shades with xterm-256 cube colors.
  var colors=['#005faf','#00875f','#af0000','#af8700','#875faf','#008787','#af005f','#5f8700',
    '#d75f5f','#00afff','#00af5f','#af5f00','#af5fff','#5f5f87','#875f00','#d75faf'];
  var colorNames=['Синий','Зелёный','Красный','Охра','Фиолетовый','Бирюзовый','Малиновый','Оливковый',
    'Коралловый','Голубой','Изумрудный','Оранжевый','Сиреневый','Сланцевый','Коричневый','Розовый'];
  function ink(color){var rgb=color.slice(1).match(/../g).map(function(v){var n=parseInt(v,16)/255;return n<=0.04045?n/12.92:Math.pow((n+0.055)/1.055,2.4);});
    var l=rgb[0]*0.2126+rgb[1]*0.7152+rgb[2]*0.0722;return l>0.179?'#000000':'#ffffff';}
  function colorOf(id){var item=draft.schedules.find(function(s){return s.id===id;});return item?colors[item.color-1]:'';}
  function nextColor(){for(var i=1;i<=16;i++)if(!draft.schedules.some(function(s){return s.color===i;}))return i;return draft.schedules.length%16+1;}
  function renderColors(){
    var currentSchedule=current(),palette=document.getElementById('schedule-colors');palette.replaceChildren();
    if(!currentSchedule)return;
    colors.forEach(function(color,i){var button=document.createElement('button');button.type='button';button.textContent=i+1;
      button.style.background=color;button.style.color=ink(color);button.title=colorNames[i];button.setAttribute('aria-label','Цвет '+(i+1)+': '+colorNames[i]);
      button.setAttribute('aria-pressed',String(currentSchedule.color===i+1));
      button.addEventListener('click',function(){currentSchedule.color=i+1;changed();render();});palette.appendChild(button);
    });
    select.style.borderLeft='10px solid '+colorOf(currentSchedule.id);
    name.style.borderLeft='10px solid '+colorOf(currentSchedule.id);
  }
  function dates(y) {
    var out=[],leap=y%4===0 && (y%100!==0 || y%400===0);
    var lengths=[31,leap?29:28,31,30,31,30,31,31,30,31,30,31];
    lengths.forEach(function(n,m){for(var d=1;d<=n;d++)out.push(String(y).padStart(4,'0')+'-'+String(m+1).padStart(2,'0')+'-'+String(d).padStart(2,'0'));});
    return out;
  }
  function weekday(date) {
    var a=date.split('-').map(Number),d=new Date(0);
    d.setUTCFullYear(a[0],a[1]-1,a[2]); d.setUTCHours(0,0,0,0);
    return (d.getUTCDay()+6)%7;
  }
  function plan(y) {return (draft.plans || []).find(function(p){return p.year===y;});}
  function assigned(p,i) {var c=p?p.days.charAt(i):'.';return c==='.'?'quiet':p.schedule_ids[c.charCodeAt(0)-65];}
  function prune(p) {
    var ids=[],out='';
    for(var i=0;i<p.days.length;i++) {
      var value=assigned(p,i);
      if(value==='quiet') {out+='.';continue;}
      var slot=ids.indexOf(value);if(slot<0){slot=ids.length;ids.push(value);}
      out+=String.fromCharCode(65+slot);
    }
    p.schedule_ids=ids;p.days=out;
  }
  function scheduleName(id) {var item=draft.schedules.find(function(s){return s.id===id;});return item?item.name:'Тихий день';}
  function paint(indices, incremental) {
    if(brush==='view' || busy || activationLock)return;
    var p=plan(year),list=dates(year),value=brush;
    if(!p && value==='quiet') return;
    if(!p) {
      if((draft.plans || []).length>=8){document.getElementById('plan-status').textContent='Уже сохранены 8 лет. Очистите ненужный год перед добавлением.';return;}
      if(!draft.plans)draft.plans=[];
      p={year:year,schedule_ids:[],days:'.'.repeat(list.length)};draft.plans.push(p);
    }
    prune(p);
    var slot=value==='quiet'?-1:p.schedule_ids.indexOf(value);
    if(value!=='quiet' && slot<0){slot=p.schedule_ids.length;p.schedule_ids.push(value);}
    var code=slot<0?'.':String.fromCharCode(65+slot),chars=p.days.split(''),didChange=false;
    indices.forEach(function(i){if(chars[i]!==code){chars[i]=code;didChange=true;}});
    p.days=chars.join('');prune(p);
    if(didChange){changed();if(incremental)refreshDays();else renderAnnual();}
  }
  function refreshDays() {
    var p=plan(year);
    document.querySelectorAll('.calendar-day').forEach(function(b){
      var sid=assigned(p,Number(b.dataset.index));
      b.title=b.dataset.date+' · '+scheduleName(sid);b.setAttribute('aria-label',b.title);
      b.style.background=sid==='quiet'?'':colorOf(sid);
      b.style.color=sid==='quiet'?'':ink(colorOf(sid));
    });
    document.getElementById('plan-status').textContent=year+': назначено '+(p?p.days.replace(/\./g,'').length:0)+' из '+dates(year).length+' дней. Остальные тихие.';
  }
  function chooseBrush(value) {brush=value;renderAnnual();}
  function renderAnnual() {
    document.getElementById('plan-year').value=year;
    var picker=document.getElementById('plan-brush');picker.replaceChildren(textOption('view','Просмотр — без изменений'),textOption('quiet','Тихий день / ластик'));
    if(brush!=='quiet' && !draft.schedules.some(function(s){return s.id===brush;}))brush='view';
    draft.schedules.forEach(function(s){picker.appendChild(textOption(s.id,s.name));});picker.value=brush;
    var legend=document.getElementById('plan-legend');legend.replaceChildren();
    [{id:'view',name:'Просмотр дня'},{id:'quiet',name:'Тихий день / ластик'}].concat(draft.schedules).forEach(function(item,i){
      var button=document.createElement('button');button.type='button';button.textContent=item.name;
      button.setAttribute('aria-pressed',String(brush===item.id));button.style.borderLeftColor=i>1?colorOf(item.id):'var(--muted)';
      button.addEventListener('click',function(){chooseBrush(item.id);});legend.appendChild(button);
    });
    document.getElementById('calendar-tool').textContent=brush==='view'?'Просмотр: нажатие даты не меняет план.':'Раскраска: '+scheduleName(brush)+'. Нажатия и протягивание меняют черновик.';
    document.getElementById('range-apply').disabled=brush==='view';
    var list=dates(year),p=plan(year),grid=document.getElementById('year-grid');grid.replaceChildren();
    var count=p?p.days.replace(/\./g,'').length:0;
    document.getElementById('plan-status').textContent=year+': назначено '+count+' из '+list.length+' дней. Остальные тихие.';
    for(var month=1;month<=12;month++) {
      var box=document.createElement('section');box.className='calendar-month';
      var title=document.createElement('h3');title.textContent=monthNames[month-1];box.appendChild(title);
      var days=document.createElement('div');days.className='month-days';
      ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'].forEach(function(w){var h=document.createElement('span');h.textContent=w;h.className='weekday';days.appendChild(h);});
      var prefix=String(year).padStart(4,'0')+'-'+String(month).padStart(2,'0')+'-';
      var first=list.indexOf(prefix+'01');
      for(var pad=0;pad<weekday(list[first]);pad++)days.appendChild(document.createElement('span'));
      list.forEach(function(date,i) {
        if(!date.startsWith(prefix))return;
        var sid=assigned(p,i),b=document.createElement('button');b.type='button';b.textContent=Number(date.slice(-2));
        b.title=date+' · '+scheduleName(sid);b.setAttribute('aria-label',b.title);b.className='calendar-day'+(weekday(date)>=5?' weekend':'');
        if(sid!=='quiet'){b.style.background=colorOf(sid);b.style.color=ink(colorOf(sid));}
        b.dataset.index=i;b.dataset.date=date;
        b.addEventListener('pointerdown',function(e){
          if(e.pointerType!=='mouse' || e.button!==0 || busy || activationLock || brush==='view')return;
          e.preventDefault();painting=true;document.getElementById('preview-date').value=date;paint([i],true);
        });
        b.addEventListener('pointerenter',function(e){
          if(painting && e.pointerType==='mouse' && (e.buttons&1) && !busy && !activationLock && brush!=='view')paint([i],true);
          if(!(e.buttons&1))painting=false;
        });
        b.addEventListener('click',function(){if(!busy && !activationLock){document.getElementById('preview-date').value=date;if(brush==='view'){window.dispatchEvent(new CustomEvent('schoolbell-open-tab',{detail:'preview'}));document.getElementById('preview-day').click();}else paint([i],true);}});
        days.appendChild(b);
      });
      box.appendChild(days);grid.appendChild(box);
    }
  }
  function id(prefix) { return prefix+'_'+Date.now().toString(36)+'_'+(++counter); }
  function current() { return draft && draft.schedules.find(function (s) { return s.id===selected; }); }
  function total() { return draft.schedules.reduce(function (n,s) { return n+s.rows.length; },0); }
  function state() {
    var locked=busy || activationLock;
    document.getElementById('workflow-draft').textContent='Черновик: '+(reconcile?'нужно сверить сохранение':!draft?'ещё не загружен':dirty?'есть несохранённые изменения':revision==='empty'?'ещё не сохранён':'сохранён · '+revision.slice(0,10));
    document.getElementById('workflow-save').disabled=locked || !draft || !dirty || reconcile;
    ['manual-media','pre-media','pre-minutes','work-mode','fixed-schedule'].forEach(function(id){document.getElementById(id).disabled=locked || !draft || (id==='fixed-schedule' && draft.mode!=='fixed');});

    document.getElementById('duty-state').textContent=busy?'Обмен с роутером…':reconcile?'Требуется сверка данных':!draft?'Данные недоступны':dirty?'Черновик изменён · не сохранён':revision==='empty'?'План ещё не сохранён':'Черновик сохранён';

    root.setAttribute('aria-busy',String(locked));
    save.textContent=busy?'Обмен с роутером…':reconcile?'Сначала сверьте сохранённое':dirty?'Сохранить черновик на роутере':'Нет изменений для сохранения';
    fields.disabled=locked || !draft;
    save.disabled=locked || !draft || !dirty || reconcile;
    reload.disabled=locked;
    document.getElementById('draft-compare').disabled=locked || !draft;
    document.getElementById('draft-keep-local').disabled=locked || !compared;
    document.getElementById('draft-use-router').disabled=locked || !compared;
    document.getElementById('settings-save').disabled=locked || !dirty || reconcile;
    document.getElementById('settings-result').textContent=result.textContent;
    badge.textContent=busy?'Обмен с роутером…':dirty?'Есть несохранённые изменения':revision==='empty'?'Пока не сохранено':'Черновик сохранён';
    badge.dataset.dirty=dirty?'true':'false';
    window.dispatchEvent(new CustomEvent('schoolbell-editor-state'));
  }
  function changed() { handoffReady=false;try{sessionStorage.removeItem(handoffKey);}catch(_){} compared=null;document.getElementById('draft-comparison').hidden=true; document.getElementById('preview-events').replaceChildren(); document.getElementById('preview-status').textContent='Черновик изменён. Обновите предпросмотр.'; dirty=true; result.textContent='Изменения только в браузере. Нажмите «Сохранить черновик». Активный план не меняется.'; state(); }
  function textOption(value,text) { var o=document.createElement('option'); o.value=value; o.textContent=text; return o; }
  function render() {
    // Legacy drafts are only materialized in browser memory; disk changes on explicit save.
    draft.schedules.forEach(function(s,i){if(s.color===undefined)s.color=i%16+1;});
    select.replaceChildren();
    draft.schedules.forEach(function (s) { var option=textOption(s.id,s.name);option.style.background=colorOf(s.id);option.style.color=ink(colorOf(s.id));select.appendChild(option); });
    if(!current()) selected=draft.schedules.length?draft.schedules[0].id:null;
    select.value=selected || '';
    var s=current();
    document.getElementById('selected-schedule').hidden=!s;
    document.getElementById('schedule-add').disabled=draft.schedules.length>=16;
    document.getElementById('schedule-copy').disabled=!s || draft.schedules.length>=16 || total()+(s?s.rows.length:0)>128;
    document.getElementById('schedule-delete').disabled=!s;
    document.getElementById('pre-minutes').value=draft.pre_minutes;
    ['manual-media','pre-media'].forEach(function(id){var box=document.getElementById(id);box.replaceChildren();mediaIds.forEach(function(m){box.appendChild(textOption(m,mediaLabel(m)));});box.value=id==='manual-media'?(draft.manual_media || 'test'):draft.pre_media;box.disabled=false;});
    if(!draft.mode)draft.mode=(draft.plans || []).length?'annual':'fixed';
    var mode=document.getElementById('work-mode');mode.disabled=false;mode.value=draft.mode;mode.querySelector('[value="annual"]').disabled=!(draft.plans || []).length;
    var fixed=document.getElementById('fixed-schedule');fixed.replaceChildren(textOption('quiet','Тихий день'));
    draft.schedules.forEach(function(s){fixed.appendChild(textOption(s.id,s.name));});
    if(draft.fixed_schedule===undefined)draft.fixed_schedule='quiet';
    fixed.value=draft.fixed_schedule;fixed.disabled=draft.mode!=='fixed';document.getElementById('pre-minutes').disabled=false;
    document.getElementById('work-mode-hint').textContent=draft.mode==='annual'?'Используется назначение датам; даты без назначения и годы без плана тихие.':'Одно расписание на каждый день. По умолчанию — тихий день.';
    rows.replaceChildren();
    if(s) {
      name.value=s.name;
      s.rows.forEach(function (row,index) {
        var tr=document.createElement('tr');
        function cell(control) { var td=document.createElement('td'); td.appendChild(control); tr.appendChild(td); }
        var time=document.createElement('input'); time.type='time'; time.step='60'; time.value=row.time;
        time.setAttribute('aria-label','Время звонка '+(index+1));
        time.addEventListener('input',function () { row.time=time.value; changed(); }); cell(time);
        var media=document.createElement('select'); media.setAttribute('aria-label','Мелодия звонка '+(index+1));
        mediaIds.forEach(function(m){media.appendChild(textOption(m,mediaLabel(m)));}); media.value=row.media;media.addEventListener('change',function(){row.media=media.value;changed();}); cell(media);
        ['enabled','pre'].forEach(function (key) {
          var box=document.createElement('input'); box.type='checkbox'; box.checked=row[key];
          box.setAttribute('aria-label',(key==='enabled'?'Включить звонок ':'Предзвонок ')+(index+1));
          box.addEventListener('change',function () { row[key]=box.checked; changed(); }); cell(box);
        });
        var del=document.createElement('button'); del.type='button'; del.textContent='×'; del.setAttribute('aria-label','Удалить звонок '+(index+1));
        del.addEventListener('click',function () { s.rows.splice(index,1); changed(); render(); }); cell(del); rows.appendChild(tr);
      });
      document.getElementById('empty-rows').hidden=s.rows.length!==0;
      document.getElementById('row-count').textContent=s.rows.length+' / 32 строк · всего '+total()+' / 128';
      document.getElementById('row-add').disabled=s.rows.length>=32 || total()>=128;
    }
    renderColors();
    renderAnnual();
    state();
  }
  var errors={
    conflict:'Расписания изменены в другой вкладке. Ваши правки сохранены в браузере. Сверьте их, затем загрузите данные роутера; автоматической перезаписи нет.',
    invalid:'Не удалось сохранить: проверьте время, название, флажки и лимиты.',
    space:'Недостаточно свободного места с защитным запасом. Черновик в браузере сохранён.',
    recovery_required:'Сохранённые данные повреждены или неполны. Они не заменены. Нужна проверка по SSH.',
    storage_unavailable:'Хранилище занято или недоступно. Изменения в браузере сохранены.',
    storage_uncertain:'Результат записи не подтверждён. Не повторяем сохранение: нажмите «Сверить с роутером».',
    revision:'Неизвестная ревизия. Загрузите данные роутера.',size:'Превышен размер черновика: 12 КиБ.'
  };
  async function request(url,options) {
    var controller=new AbortController(),timer=setTimeout(function(){controller.abort();},15000);
    try {
      var response=await fetch(url,Object.assign({credentials:'same-origin',cache:'no-store',redirect:'error',signal:controller.signal},options));
      if(!response.ok) throw new Error('http');
      return await response.json();
    } finally {clearTimeout(timer);}

  }
  function prepareNavigation(){
    try{
      if(dirty && draft){
        var text=JSON.stringify({user:document.getElementById('session-panel').dataset.user,until:Date.now()+8*3600000,revision:revision,selected:selected,year:year,data:draft});
        if(text.length>32768)return false;
        sessionStorage.setItem(handoffKey,text);
        if(sessionStorage.getItem(handoffKey)!==text)return false;
      }else sessionStorage.removeItem(handoffKey);
      handoffReady=true;return true;
    }catch(_){return false;}
  }
  function restoreNavigation(){
    try{
      var text=sessionStorage.getItem(handoffKey);if(!text)return false;
      sessionStorage.removeItem(handoffKey);
      if(text.length>32768)return false;var kept=JSON.parse(text);
      if(kept.user!==document.getElementById('session-panel').dataset.user || typeof kept.until!=='number' || !Number.isFinite(kept.until) || kept.until<Date.now() || kept.until>Date.now()+8*3600000 || typeof kept.revision!=='string' || !kept.data || !Array.isArray(kept.data.schedules))return false;
      var local=normalize(kept.data);if(local.schedules.length>16 || (local.plans || []).length>8)return false;
      reconcile=kept.revision!==revision;draft=local;selected=local.schedules.some(function(s){return s.id===kept.selected;})?kept.selected:null;if(Number.isInteger(kept.year)&&kept.year>=1970&&kept.year<=9999)year=kept.year;dirty=true;return true;
    }catch(_){return false;}
  }
  async function load() {
    if(busy || activationLock)return;
    if(dirty && !window.confirm('Заменить несохранённые изменения данными с роутера?')) return;
    busy=true; state();
    try {
      var value=await request(root.dataset.load);
      if(!value.ok) { result.textContent=errors[value.code] || 'Ошибка чтения.'; reconcile=true; return; }
      document.getElementById('preview-events').replaceChildren(); document.getElementById('preview-status').textContent='Предпросмотр использует текущий черновик.'; draft=value.data; revision=value.revision; dirty=false; reconcile=false; compared=null;document.getElementById('draft-comparison').hidden=true; brush='view'; render();
      result.textContent=revision==='empty'?'Сохранённых расписаний ещё нет. Создайте первое.':'Черновик прочитан с роутера. Состояние автозвонков указано в верхней плашке.';
      if(restoreNavigation()){render();result.textContent=reconcile?'Правки восстановлены. Сохранённый план изменился: сверьте копии перед записью.':'Несохранённые правки восстановлены после входа. Автозвонки не включались.';}
    } catch (_) { result.textContent='Не удалось загрузить данные. Проверьте соединение и вход LuCI.'; }
    finally { busy=false; state(); }
  }
  function canonical(value) {
    if(Array.isArray(value))return '['+value.map(canonical).join(',')+']';
    if(value && typeof value==='object')return '{'+Object.keys(value).sort().map(function(k){return JSON.stringify(k)+':'+canonical(value[k]);}).join(',')+'}';
    return JSON.stringify(value);
  }
  function normalize(value) {
    var data=JSON.parse(JSON.stringify(value));
    data.schedules.forEach(function(s,i){if(s.color===undefined)s.color=i%16+1;});
    if(data.mode===undefined)data.mode=(data.plans || []).length?'annual':'fixed';
    if(data.fixed_schedule===undefined)data.fixed_schedule='quiet';
    return data;
  }
  function describe(data) {
    var mode=data.mode==='annual'?'Годовой план':'По расписанию';
    var fixed=data.schedules.find(function(s){return s.id===data.fixed_schedule;});
    return mode+' · ежедневное: '+(fixed?fixed.name:'Тихий день')+' · расписания: '+data.schedules.map(function(s){return s.name+' ('+s.rows.length+' строк)';}).join(', ')+' · годы: '+(data.plans || []).map(function(p){return p.year+' ('+p.days.replace(/\./g,'').length+' назначений)';}).join(', ')+' · предзвонок: '+data.pre_minutes+' мин, '+data.pre_media+' · ручной: '+(data.manual_media || 'test');
  }
  async function compare() {
    if(busy || activationLock || !draft)return;
    busy=true;compared=null;document.getElementById('draft-comparison').hidden=true;state();
    try {
      var value=await request(root.dataset.load);
      if(!value.ok)throw Error('read');
      var remote=normalize(value.data);
      compared={data:remote,revision:value.revision};reconcile=true;
      document.getElementById('draft-local-summary').textContent='Локально: '+describe(draft);
      document.getElementById('draft-router-summary').textContent='Сохранено: '+describe(remote);
      document.getElementById('draft-local-json').textContent=JSON.stringify(draft,null,2);
      document.getElementById('draft-router-json').textContent=JSON.stringify(remote,null,2);
      document.getElementById('draft-comparison-status').textContent=(canonical(draft)===canonical(remote)?'Данные совпадают.':'Данные различаются.')+' На роутере: '+value.revision+'. Выберите, какую копию оставить в редакторе. Это не сохранение и не включение звонков.';
      document.getElementById('draft-comparison').hidden=false;
      result.textContent='Сверка прочитана. Локальные правки сохранены; выберите копию ниже.';
    } catch(_){reconcile=true;result.textContent='Сверка недоступна. Локальные правки сохранены. Проверьте соединение и вход LuCI, затем повторите чтение.';}
    finally{busy=false;state();}
  }
  function chooseCompared(local) {
    if(busy || activationLock || !compared)return;
    if(!window.confirm(local?'Оставить локальную копию для следующего явного сохранения поверх проверенной версии роутера? Изменения другого редактора могут быть заменены.':'Заменить правки в браузере проверенной копией роутера?'))return;
    var same=canonical(draft)===canonical(compared.data);
    if(!local)draft=compared.data;
    revision=compared.revision;dirty=local && !same;reconcile=false;compared=null;
    document.getElementById('draft-comparison').hidden=true;
    document.getElementById('preview-events').replaceChildren();document.getElementById('preview-status').textContent='Черновик сверен. Обновите предпросмотр.';
    render();result.textContent=dirty?'Локальные правки оставлены. Для записи нажмите «Сохранить черновик». Активный план не менялся.':'Копия сверена. Автозвонки не включались.';state();
  }
  document.getElementById('draft-compare').addEventListener('click',compare);
  document.getElementById('draft-keep-local').addEventListener('click',function(){chooseCompared(true);});
  document.getElementById('draft-use-router').addEventListener('click',function(){chooseCompared(false);});
  select.addEventListener('change',function () { selected=select.value; render(); });
  name.addEventListener('input',function () {
    if(!current()) return; current().name=name.value;
    select.options[select.selectedIndex].textContent=name.value; changed(); renderAnnual();
  });
  document.getElementById('settings-save').addEventListener('click',function(){save.click();});
  [['manual-media','manual_media'],['pre-media','pre_media'],['work-mode','mode'],['fixed-schedule','fixed_schedule']].forEach(function(pair){document.getElementById(pair[0]).addEventListener('change',function(e){draft[pair[1]]=e.target.value;changed();render();});});
  document.getElementById('pre-minutes').addEventListener('input',function (e) { draft.pre_minutes=Number(e.target.value); changed(); });
  document.getElementById('schedule-add').addEventListener('click',function () {
    if(draft.schedules.length>=16) return;
    var s={id:id('schedule'),name:'Новое расписание',color:nextColor(),rows:[]}; draft.schedules.push(s); selected=s.id; changed(); render(); name.focus(); name.select();
  });
  document.getElementById('schedule-copy').addEventListener('click',function () {
    if(!current() || draft.schedules.length>=16 || total()+current().rows.length>128) return;
    var s=JSON.parse(JSON.stringify(current())); s.id=id('schedule'); s.color=nextColor(); s.name=Array.from(s.name).slice(0,20).join('')+' — копия';
    draft.schedules.push(s); selected=s.id; changed(); render();
  });
  document.getElementById('schedule-delete').addEventListener('click',function () {
    if(!current() || busy || activationLock)return;
    if(draft.fixed_schedule===selected){result.textContent='Это ежедневное расписание. В «Настройках» явно выберите другое или «Тихий день», затем повторите удаление. Активный план не меняется.';return;}
    var used=(draft.plans || []).some(function(p){var i=p.schedule_ids.indexOf(selected);return i>=0 && p.days.includes(String.fromCharCode(65+i));});
    if(used){result.textContent='Расписание назначено датам. Сначала снимите назначения во всех годах.';return;}
    if(!window.confirm('Удалить расписание «'+current().name+'» из черновика? Активный план не изменится.'))return;
    (draft.plans || []).forEach(prune);
    draft.schedules=draft.schedules.filter(function (s) { return s.id!==selected; }); selected=null; changed(); render();
  });
  document.getElementById('row-add').addEventListener('click',function () {
    var s=current(); if(!s || s.rows.length>=32 || total()>=128) return;
    s.rows.push({id:id('row'),time:'08:00',media:'test',enabled:true,pre:false}); changed(); render();
  });
  document.getElementById('rows-clear').addEventListener('click',function () {
    if(!current() || !window.confirm('Очистить все строки выбранного расписания?')) return;
    current().rows=[]; changed(); render();
  });
  save.addEventListener('click',async function () {
    if(busy || activationLock || !draft || !dirty || reconcile)return;
    busy=true; state(); result.textContent='Сохраняем без активации…';
    try {
      var body=new URLSearchParams({token:root.dataset.token,revision:revision,draft:JSON.stringify(draft)});
      var value=await request(root.dataset.save,{method:'POST',body:body});
      if(!value.ok) {
        reconcile=['storage_uncertain','recovery_required','conflict'].includes(value.code);
        result.textContent=(errors[value.code] || 'Ошибка сохранения.')+(value.detail?' Поле: '+(value.detail.path || value.detail.code):'');
        return;
      }
      document.getElementById('preview-events').replaceChildren(); document.getElementById('preview-status').textContent='Предпросмотр использует текущий черновик.'; draft=value.data; revision=value.revision; dirty=false; reconcile=false; render();
      result.textContent='Сохранено на роутере. Активный план не меняется до отдельного применения.'+(value.journal_warning?' Внимание: событие не удалось записать в журнал.':'');
    } catch (_) { reconcile=true; result.textContent='Ответ потерян: запись могла завершиться. Правки остались в браузере. Нажмите «Сверить с роутером».'; }
    finally { busy=false; state(); }
  });
  document.getElementById('year-show').addEventListener('click',function(){
    var value=Number(document.getElementById('plan-year').value);
    if(!Number.isInteger(value) || value<1 || value>9999){result.textContent='Год должен быть от 1 до 9999.';return;}
    year=value;var list=dates(year);document.getElementById('range-first').value=list[0];document.getElementById('range-last').value=list[list.length-1];renderAnnual();
  });
  document.getElementById('plan-brush').addEventListener('change',function(e){chooseBrush(e.target.value);});
  document.getElementById('range-apply').addEventListener('click',function(){
    if(brush==='view' || busy || activationLock)return;
    var list=dates(year),first=list.indexOf(document.getElementById('range-first').value),last=list.indexOf(document.getElementById('range-last').value);
    if(first<0 || last<first){document.getElementById('plan-status').textContent='Укажите корректный диапазон внутри выбранного года.';return;}
    var filter=document.getElementById('range-filter').value,indices=[];
    for(var i=first;i<=last;i++){var w=weekday(list[i]);if(filter==='all' || (filter==='weekdays' && w<5) || (filter==='weekends' && w>=5))indices.push(i);}
    if(indices.length && window.confirm('Назначить «'+scheduleName(brush)+'» для '+indices.length+' дат?'))paint(indices);
  });
  document.getElementById('year-clear').addEventListener('click',function(){
    if(!plan(year) || busy || activationLock)return;
    var lastAnnual=draft.mode==='annual' && draft.plans.length===1;
    var consequence=lastAnnual?' Это последний год. В черновике будет выбран режим «По расписанию» и «Тихий день».':'';
    if(window.confirm('Снять все назначения '+year+' года?'+consequence+' Активный план не изменится; черновик потребуется сохранить и применить отдельно.')){
      draft.plans=draft.plans.filter(function(p){return p.year!==year;});if(lastAnnual){draft.mode='fixed';draft.fixed_schedule='quiet';}changed();render();
    }
  });
  document.getElementById('preview-day').addEventListener('click',async function(){
    if(busy || activationLock || !draft)return;
    busy=true;state();var status=document.getElementById('preview-status'),output=document.getElementById('preview-events');output.replaceChildren();
    status.textContent='Вычисляем текущий черновик без сохранения и звука…';
    try {
      var value=await request(root.dataset.preview,{method:'POST',body:new URLSearchParams({token:root.dataset.token,draft:JSON.stringify(draft),date:document.getElementById('preview-date').value})});
      if(!value.ok){status.textContent='Предпросмотр отклонён: '+(value.detail?(value.detail.path || value.detail.code):value.code);return;}
      status.textContent='Черновик'+(dirty || revision==='empty'?' · НЕ СОХРАНЁН':' · сохранён')+' · '+value.date+' · '+scheduleName(value.selected_schedule)+' · '+value.events.length+' событий. Местные часы; не UTC и не проверка переходов часов.';
      value.events.forEach(function(e){var li=document.createElement('li');li.style.borderLeft='10px solid '+colorOf(e.schedule_id);li.style.paddingLeft='10px';li.textContent=e.time+' — '+(e.kind==='pre'?'Предзвонок':'Основной звонок')+' · '+scheduleName(e.schedule_id)+' · '+e.media+(e.origin_date!==e.date?' (основной звонок '+e.origin_date+')':'');output.appendChild(li);});
      if(!value.events.length){var li=document.createElement('li');li.textContent='В этот день звонков нет.';output.appendChild(li);}
    } catch(_){status.textContent='Предпросмотр недоступен. Проверьте соединение и вход LuCI.';}
    finally{busy=false;state();}
  });
  window.addEventListener('pointerup',function(){painting=false;});
  window.addEventListener('pointercancel',function(){painting=false;});
  window.addEventListener('blur',function(){painting=false;});
  var initialDates=dates(year);
  document.getElementById('range-first').value=initialDates[0];document.getElementById('range-last').value=initialDates[initialDates.length-1];
  document.getElementById('preview-date').value=initialDates[0];
  window.schoolbellEditor={prepareNavigation:prepareNavigation,snapshot:function(){return {loaded:!!draft,dirty:dirty,busy:busy || activationLock,reconcile:reconcile,revision:revision};},lock:function(){if(busy || activationLock || !draft || dirty || reconcile || revision==='empty')return false;activationLock=true;state();return true;},unlock:function(){activationLock=false;state();}};
  document.getElementById('workflow-save').addEventListener('click',function(){save.click();});
  reload.addEventListener('click',load);
  window.addEventListener('beforeunload',function (e) { if(dirty && !handoffReady) { e.preventDefault(); e.returnValue=''; } });
  window.addEventListener('schoolbell-session-lost',function(){
    reconcile=true;compared=null;document.getElementById('draft-comparison').hidden=true;
    result.textContent='Сеанс недоступен. Правки остаются в этой вкладке; после входа нажмите «Сверить с роутером».';state();
  });
  load();
}());
