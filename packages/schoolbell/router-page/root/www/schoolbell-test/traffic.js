/* Passive, tab-local API counters; no requests, storage or payload inspection. */
(function(global){
  'use strict';
  function create(clock){
    var slots=[],pending=0;
    function bucket(){var key=Math.floor(clock()/5000),b=slots.find(function(x){return x.key===key;});
      slots=slots.filter(function(x){return x.key>key-12;});
      if(!b){b={key:key,reads:0,commands:0,errors:0,finished:0,total:0,max:0};slots.push(b);}return b;}
    return {
      begin:function(method){var b=bucket();b[method==='GET'||method==='HEAD'?'reads':'commands']++;pending++;return {bucket:b,start:clock(),done:false};},
      end:function(ticket,failed){if(ticket.done)return;ticket.done=true;pending--;var b=ticket.bucket,ms=Math.max(0,clock()-ticket.start);b.finished++;b.total+=ms;b.max=Math.max(b.max,ms);if(failed)b.errors++;},
      snapshot:function(){var current=bucket(),items=[];for(var key=current.key-11;key<=current.key;key++){var b=slots.find(function(x){return x.key===key;});items.push(Object.assign({key:key,reads:0,commands:0,errors:0,finished:0,total:0,max:0},b));}return {items:items,pending:pending};}
    };
  }
  function observe(fetcher,model,accept){return function(input,options){
    if(!accept(input))return fetcher(input,options);
    var ticket=model.begin(String(options&&options.method || input&&input.method || 'GET').toUpperCase());
    try{return Promise.resolve(fetcher(input,options)).then(function(response){model.end(ticket,!response.ok);return response;},function(error){model.end(ticket,true);throw error;});}
    catch(error){model.end(ticket,true);throw error;}
  };}
  if(typeof module==='object'&&module.exports){module.exports={create:create,observe:observe};return;}
  var chart=document.getElementById('traffic-chart');if(!chart)return;
  var root=document.getElementById('schedule-editor'),panel=document.getElementById('session-panel');
  var endpoints=new Set(),data=Object.assign({},root.dataset,{session:panel.dataset.session,backup:document.getElementById('backup-panel')?.dataset.url});
  // Only explicitly supplied module endpoints, never unrelated fetches or audio streams.
  ['media','trust','automatic','controls','manual','timezone','journal','clock','preview','load','save','session','backup'].forEach(function(key){if(!data[key])return;try{var u=new URL(data[key],location.href);if(u.origin===location.origin&&key!=='sample')endpoints.add(u.pathname);}catch(_){}});
  var form=document.getElementById('router-form');if(form)endpoints.add(new URL(form.action,location.href).pathname);
  var model=create(function(){return performance.now();});
  global.fetch=observe(global.fetch.bind(global),model,function(input){try{var u=new URL(typeof input==='string'?input:input.url,location.href);return u.origin===location.origin&&endpoints.has(u.pathname);}catch(_){return false;}});
  var ns='http://www.w3.org/2000/svg';
  function svg(tag,attrs){var el=document.createElementNS(ns,tag);Object.keys(attrs).forEach(function(k){el.setAttribute(k,attrs[k]);});return el;}
  var selectedKey=null;
  var hint=document.getElementById('traffic-hint');
  function choose(index){var s=model.snapshot();selectedKey=s.items[Math.max(0,Math.min(11,index))].key;render();}
  function point(event){var rect=chart.getBoundingClientRect();if(rect.width>0)choose(Math.round(((event.clientX-rect.left)*700/rect.width-20)/60));}
  chart.addEventListener('pointermove',point);chart.addEventListener('click',point);
  chart.addEventListener('focus',function(){if(selectedKey===null)choose(11);});
  chart.addEventListener('keydown',function(event){
    if(['ArrowLeft','ArrowRight','Home','End'].indexOf(event.key)<0)return;
    event.preventDefault();var items=model.snapshot().items,index=items.findIndex(function(b){return b.key===selectedKey;});
    choose(event.key==='Home'?0:event.key==='End'?11:(index<0?11:index)+(event.key==='ArrowLeft'?-1:1));
  });
  function render(){
    var s=model.snapshot(),sum={reads:0,commands:0,errors:0,finished:0,total:0,max:0},peak=1;
    s.items.forEach(function(b){Object.keys(sum).forEach(function(k){if(k==='max')sum[k]=Math.max(sum[k],b[k]);else sum[k]+=b[k];});peak=Math.max(peak,b.reads,b.commands);});
    chart.replaceChildren();
    var selected=s.items.find(function(b){return b.key===selectedKey;});
    if(selected){
      var index=s.items.indexOf(selected),age=Math.max(0,Math.floor((performance.now()-selected.key*5000)/1000));
      hint.textContent='Интервал '+Math.max(0,age-5)+'–'+age+' с назад'+(index===11?' (текущий)':'')+': всего '+(selected.reads+selected.commands)+' · чтение '+selected.reads+' · команды '+selected.commands+' · ошибки HTTP/сети '+selected.errors;
      chart.appendChild(svg('line',{x1:20+index*60,x2:20+index*60,y1:5,y2:120,class:'traffic-selection'}));
    }else{selectedKey=null;hint.textContent='Наведите на точку или нажмите её. Клавиатура: ← / →, Home / End.';}

    ['reads','commands'].forEach(function(kind){var points=[];s.items.forEach(function(b,i){points.push((20+i*60)+','+(110-b[kind]/peak*90));});chart.appendChild(svg('polyline',{points:points.join(' '),class:'traffic-'+kind,fill:'none','stroke-width':2}));
      s.items.forEach(function(b,i){var dot=svg('circle',{cx:20+i*60,cy:110-b[kind]/peak*90,r:4,class:'traffic-'+kind});var title=svg('title',{});title.textContent=(kind==='reads'?'Чтение':'Команды')+': '+b[kind]+'; интервал '+(i+1)+' из 12';dot.appendChild(title);chart.appendChild(dot);});});
    document.getElementById('traffic-scale').textContent='Шкала: 0–'+peak+' запросов за 5 с · последний интервал ещё заполняется';
    document.getElementById('traffic-stats').textContent='Чтение: '+sum.reads+' · Команды: '+sum.commands+' · Ошибки HTTP/сети: '+sum.errors+' · Ожидают HTTP: '+s.pending+' · До заголовков HTTP, среднее / максимум: '+(sum.finished?Math.round(sum.total/sum.finished)+' / '+Math.round(sum.max)+' мс':'нет завершённых запросов');
  }
  if(panel.dataset.session.indexOf('/demo-api/')!==-1)document.getElementById('traffic-mode').textContent='Демо: обращения к локальной модели, не измерение устройства.';
  render();setInterval(function(){if(!document.hidden&&!document.getElementById('panel-journal').hidden)render();},1000);
})(typeof window==='object'?window:globalThis);
