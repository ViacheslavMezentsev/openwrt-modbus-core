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
  var draft=null, revision=null, selected=null, dirty=false, busy=false, reconcile=false;
  var counter=0;
  function id(prefix) { return prefix+'_'+Date.now().toString(36)+'_'+(++counter); }
  function current() { return draft && draft.schedules.find(function (s) { return s.id===selected; }); }
  function total() { return draft.schedules.reduce(function (n,s) { return n+s.rows.length; },0); }
  function state() {
    fields.disabled=busy || !draft;
    save.disabled=busy || !draft || !dirty || reconcile;
    reload.disabled=busy;
    badge.textContent=busy?'Обмен с роутером…':dirty?'Есть несохранённые изменения':revision==='empty'?'Пока не сохранено':'Сохранено · не активно';
    badge.dataset.dirty=dirty?'true':'false';
  }
  function changed() { dirty=true; result.textContent='Изменения только в браузере. Нажмите «Сохранить черновик». Автозвонков нет.'; state(); }
  function textOption(value,text) { var o=document.createElement('option'); o.value=value; o.textContent=text; return o; }
  function render() {
    select.replaceChildren();
    draft.schedules.forEach(function (s) { select.appendChild(textOption(s.id,s.name)); });
    if(!current()) selected=draft.schedules.length?draft.schedules[0].id:null;
    select.value=selected || '';
    var s=current();
    document.getElementById('selected-schedule').hidden=!s;
    document.getElementById('schedule-add').disabled=draft.schedules.length>=16;
    document.getElementById('schedule-copy').disabled=!s || draft.schedules.length>=16 || total()+(s?s.rows.length:0)>128;
    document.getElementById('schedule-delete').disabled=!s;
    document.getElementById('pre-minutes').value=draft.pre_minutes;
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
        media.appendChild(textOption('test','test.mp3')); media.value=row.media; cell(media);
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
    state();
  }
  var errors={
    conflict:'Расписания изменены в другой вкладке. Ваши правки сохранены в браузере. Сверьте их, затем загрузите данные роутера; автоматической перезаписи нет.',
    invalid:'Не удалось сохранить: проверьте время, название, флажки и лимиты.',
    space:'Недостаточно свободного места с защитным запасом. Черновик в браузере сохранён.',
    recovery_required:'Сохранённые данные повреждены или неполны. Они не заменены. Нужна проверка по SSH.',
    storage_unavailable:'Хранилище занято или недоступно. Изменения в браузере сохранены.',
    storage_uncertain:'Результат записи не подтверждён. Не повторяем сохранение: загрузите данные роутера и сравните.',
    revision:'Неизвестная ревизия. Загрузите данные роутера.',size:'Превышен размер черновика: 12 КиБ.'
  };
  async function request(url,options) {
    var response=await fetch(url,Object.assign({credentials:'same-origin',cache:'no-store',redirect:'error'},options));
    if(!response.ok) throw new Error('http');
    return response.json();
  }
  async function load() {
    if(dirty && !window.confirm('Заменить несохранённые изменения данными с роутера?')) return;
    busy=true; state();
    try {
      var value=await request(root.dataset.load);
      if(!value.ok) { result.textContent=errors[value.code] || 'Ошибка чтения.'; reconcile=true; return; }
      draft=value.data; revision=value.revision; dirty=false; reconcile=false; render();
      result.textContent=revision==='empty'?'Сохранённых расписаний ещё нет. Создайте первое.':'Данные прочитаны с роутера. Автоматическое воспроизведение отключено.';
    } catch (_) { result.textContent='Не удалось загрузить данные. Проверьте соединение и вход LuCI.'; }
    finally { busy=false; state(); }
  }
  select.addEventListener('change',function () { selected=select.value; render(); });
  name.addEventListener('input',function () {
    if(!current()) return; current().name=name.value;
    select.options[select.selectedIndex].textContent=name.value; changed();
  });
  document.getElementById('pre-minutes').addEventListener('input',function (e) { draft.pre_minutes=Number(e.target.value); changed(); });
  document.getElementById('schedule-add').addEventListener('click',function () {
    if(draft.schedules.length>=16) return;
    var s={id:id('schedule'),name:'Новое расписание',rows:[]}; draft.schedules.push(s); selected=s.id; changed(); render(); name.focus(); name.select();
  });
  document.getElementById('schedule-copy').addEventListener('click',function () {
    if(!current() || draft.schedules.length>=16 || total()+current().rows.length>128) return;
    var s=JSON.parse(JSON.stringify(current())); s.id=id('schedule'); s.name=Array.from(s.name).slice(0,20).join('')+' — копия';
    draft.schedules.push(s); selected=s.id; changed(); render();
  });
  document.getElementById('schedule-delete').addEventListener('click',function () {
    if(!current() || !window.confirm('Удалить расписание «'+current().name+'» из черновика?')) return;
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
    busy=true; state(); result.textContent='Сохраняем без активации…';
    try {
      var body=new URLSearchParams({token:root.dataset.token,revision:revision,draft:JSON.stringify(draft)});
      var value=await request(root.dataset.save,{method:'POST',body:body});
      if(!value.ok) {
        reconcile=['storage_uncertain','recovery_required','conflict'].includes(value.code);
        result.textContent=(errors[value.code] || 'Ошибка сохранения.')+(value.detail?' Поле: '+(value.detail.path || value.detail.code):'');
        return;
      }
      draft=value.data; revision=value.revision; dirty=false; reconcile=false; render();
      result.textContent='Сохранено на роутере. Автоматические звонки не включены.';
    } catch (_) { reconcile=true; result.textContent='Ответ потерян: запись могла завершиться. Правки остались в браузере. Загрузите данные роутера и сравните.'; }
    finally { busy=false; state(); }
  });
  reload.addEventListener('click',load);
  window.addEventListener('beforeunload',function (e) { if(dirty) { e.preventDefault(); e.returnValue=''; } });
  load();
}());
