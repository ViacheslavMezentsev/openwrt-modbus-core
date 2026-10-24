(function () {
  'use strict';
  var root=document.getElementById('schedule-editor'),panel=document.getElementById('duty-panel');
  var tabs=Array.from(document.querySelectorAll('[data-tab]'));
  function selectTab(name) {
    tabs.forEach(function(b){var active=b.dataset.tab===name;b.setAttribute('aria-selected',String(active));b.tabIndex=active?0:-1;});
    document.querySelectorAll('[data-panel]').forEach(function(p){p.hidden=p.dataset.panel!==name;});
    root.hidden=name==='sound' || name==='journal' || name==='feedback';
    if(name==='journal')loadJournal();
    document.querySelector('.savebar').hidden=name==='preview';
    try{sessionStorage.setItem('schoolbell-tab',name);}catch(_){}
  }
  var journalBusy=false;
  var actions={save_ok:'Черновик сохранён',save_failed:'Сохранение отклонено',preview_ok:'Запрошен предпросмотр',preview_failed:'Предпросмотр отклонён',play_requested:'Запрошен звук на роутере',play_ok:'Проигрыватель завершился успешно',play_failed:'Ошибка проигрывателя',sample_requested:'Передан файл для браузера (не подтверждение звука)',storage_error:'Ошибка хранилища',installed:'Установлен интерфейс schoolbell'};
  async function loadJournal(){
    if(journalBusy)return;journalBusy=true;
    var button=document.getElementById('journal-reload'),status=document.getElementById('journal-status');button.disabled=true;
    var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},10000);
    try{
      var response=await fetch(root.dataset.journal,{credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal});
      if(!response.ok)throw new Error('http');var value=await response.json();if(!value.ok)throw new Error('journal');
      var rows=document.getElementById('journal-rows');rows.replaceChildren();
      value.entries.slice().reverse().forEach(function(e){var tr=document.createElement('tr');tr.className='journal-'+e.level;
        ['#'+e.seq+' · '+new Date(e.time*1000).toISOString().replace('T',' ').replace('.000Z',' UTC'),{user:'Пользователь',module:'Модуль',system:'Система'}[e.source],actions[e.action] || e.action].forEach(function(text){var td=document.createElement('td');td.textContent=text;tr.appendChild(td);});rows.appendChild(tr);});
      status.textContent=value.entries.length?'Показано '+value.entries.length+' записей.':'Журнал пока пуст.';
    }catch(_){status.textContent='Не удалось прочитать журнал. Предыдущие строки могут быть устаревшими; проверьте связь и хранилище.';}
    finally{clearTimeout(timer);button.disabled=false;journalBusy=false;}
  }
  document.getElementById('journal-reload').addEventListener('click',loadJournal);
  tabs.forEach(function(b,index){
    b.addEventListener('click',function(){selectTab(b.dataset.tab);});
    b.addEventListener('keydown',function(e){
      var i=index;
      if(e.key==='ArrowRight')i=(i+1)%tabs.length;
      else if(e.key==='ArrowLeft')i=(i+tabs.length-1)%tabs.length;
      else if(e.key==='Home')i=0;
      else if(e.key==='End')i=tabs.length-1;
      else return;
      e.preventDefault();selectTab(tabs[i].dataset.tab);tabs[i].focus();
    });
  });
  try{var saved=sessionStorage.getItem('schoolbell-tab');if(tabs.some(function(b){return b.dataset.tab===saved;}))selectTab(saved);
    panel.open=localStorage.getItem('schoolbell-status-collapsed')!=='true';}catch(_){}
  panel.addEventListener('toggle',function(){try{localStorage.setItem('schoolbell-status-collapsed',String(!panel.open));}catch(_){} });
  var sample=null,inflight=false;
  var format={weekday:'long',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false};
  function zone(minutes){return 'UTC'+(minutes>=0?'+':'−')+String(Math.floor(Math.abs(minutes)/60)).padStart(2,'0')+':'+String(Math.abs(minutes)%60).padStart(2,'0');}
  function draw() {
    var browser=new Date(),elapsed=sample?performance.now()-sample.received:Infinity;
    document.getElementById('browser-clock').textContent=browser.toLocaleString('ru-RU',format);
    document.getElementById('browser-zone').textContent=Intl.DateTimeFormat().resolvedOptions().timeZone+' · '+zone(-browser.getTimezoneOffset());
    var status=document.getElementById('clock-status'),sync=document.getElementById('clock-sync');sync.hidden=true;document.getElementById('timezone-hint').hidden=true;
    if(!sample || elapsed>90000){document.getElementById('router-clock').textContent='Время недоступно';status.textContent='Нет свежего ответа роутера. Сравнение часов отключено.';return;}
    document.getElementById('router-clock').textContent=new Date(sample.wall+elapsed).toLocaleString('ru-RU',Object.assign({},format,{timeZone:'UTC'}));
    document.getElementById('router-zone').textContent=zone(sample.offset)+' · получено '+Math.floor(elapsed/1000)+' с назад';
    document.getElementById('timezone-hint').hidden=sample.offset===-browser.getTimezoneOffset();
    var delta=(browser.getTime()-(sample.epoch+elapsed))/1000;
    if(sample.rtt>2000){status.textContent='Медленный ответ роутера: сравнение неточно. Ожидаем следующий опрос.';return;}
    if(Math.abs(delta)>5){status.textContent='Часы роутера '+(delta>0?'отстают':'спешат')+' примерно на '+Math.round(Math.abs(delta))+' с относительно браузера.';sync.hidden=false;}
    else status.textContent='Часы совпадают в пределах 5 с.';
    if(sample.offset!==-browser.getTimezoneOffset())status.textContent+=' Часовые пояса различаются; синхронизация времени не меняет пояс.';
  }
  async function poll() {
    if(inflight || document.hidden)return;
    inflight=true;var started=performance.now(),abort=new AbortController(),timer=setTimeout(function(){abort.abort();},10000);
    try{
      var response=await fetch(root.dataset.clock,{credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal});
      if(!response.ok)throw new Error('http');
      var v=await response.json(),received=performance.now(),rtt=received-started;
      if(!v.ok || !Number.isInteger(v.epoch) || !['year','month','day','hour','min','sec'].every(function(k){return Number.isInteger(v[k]);}))throw new Error('clock');
      var wall=Date.UTC(v.year,v.month-1,v.day,v.hour,v.min,v.sec);
      sample={received:received,epoch:v.epoch*1000+rtt/2,wall:wall+rtt/2,offset:Math.round((wall-v.epoch*1000)/60000),rtt:rtt};
    }catch(_){sample=null;}
    finally{clearTimeout(timer);inflight=false;draw();}
  }
  document.addEventListener('visibilitychange',function(){if(!document.hidden){sample=null;poll();}});
  draw();poll();setInterval(poll,30000);setInterval(draw,1000);
}());
