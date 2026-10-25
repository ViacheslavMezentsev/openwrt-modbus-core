(function(){
'use strict';
var root=document.getElementById('schedule-editor'),on=document.getElementById('automatic-enable'),off=document.getElementById('automatic-disable'),message=document.getElementById('automatic-status');
var busy=false,reading=false,sample=null,feedback='';
var names={backward_hold:'Часы переведены назад: ожидание прежней границы времени',disabled:'Автозвонки отключены',running:'Автозвонки включены',muted:'Автозвонки · Mute',playing:'Выполняется звонок',waiting:'Нет свежего подтверждения службы',confirm_clock:'После перезагрузки проверьте часы и включите снова',timezone_changed:'Пояс изменён: проверьте часы и включите снова',clock_invalid:'Недопустимая дата роутера',control_unreadable:'Не читается Mute',claim_failed:'Ошибка фиксации звонка',nonexistent_time:'В плане есть несуществующее местное время',ambiguous_time:'В плане есть неоднозначное местное время',simultaneous_events:'Несколько звонков назначены на одно время',calendar_invalid:'Ошибка календаря',executor_error:'Ошибка исполнителя',busy:'Звонок пропущен: проигрыватель занят',unavailable:'Исполнитель недоступен',recovery_required:'Проигрыватель требует проверки',expired:'Просроченный звонок пропущен',clock_gap:'Пропуск после скачка часов или задержки'};
async function request(url,body){var abort=new AbortController(),timer=setTimeout(function(){abort.abort();},12000);try{var o={credentials:'same-origin',cache:'no-store',redirect:'error',signal:abort.signal};if(body){o.method='POST';o.body=new URLSearchParams(Object.assign({token:root.dataset.token},body));}var response=await fetch(url,o);if(!response.ok)throw Error('HTTP');return await response.json();}finally{clearTimeout(timer);}}
function draw(){
 var fresh=sample && performance.now()-sample.at<15000,v=fresh?sample.value:null;
 var label=v?(names[v.state] || v.state):'Нет свежего ответа исполнителя';
 document.getElementById('duty-compact').textContent=label;
 document.getElementById('automatic-mode').textContent=label+(v && v.mode?' · '+(v.mode==='annual'?'Годовой план':'Ежедневное расписание'):'');
 var remaining=v && v.next?Math.ceil(v.next.utc-v.now-(performance.now()-sample.at)/1000):null;
 document.getElementById('automatic-next').textContent=remaining!==null && remaining>0?(v.state==='muted'?'Будет пропущен · ':'')+Math.floor(remaining/3600)+' ч '+Math.floor(remaining%3600/60)+' мин '+remaining%60+' с':'—';
 document.getElementById('automatic-detail').textContent=v && v.next?'Сегодня '+v.next.time+' · '+(v.next.kind==='pre'?'предзвонок':'основной звонок'):'Сегодня нет следующего звонка или исполнитель не готов.';
 if(!busy)message.textContent=feedback+label+(v && v.revision?' · активная ревизия '+v.revision.slice(0,10):'');
 on.disabled=busy || !!(v && v.hardware===false);off.disabled=busy || !!(v && v.hardware===false);
}
async function refresh(){if(reading || busy || document.hidden)return;reading=true;try{var v=await request(root.dataset.automatic);sample={value:v,at:performance.now()};}catch(_){sample=null;}finally{reading=false;draw();}}
async function change(enabled){if(busy)return;busy=true;feedback='';draw();try{
 var revision='';if(enabled){var saved=await request(root.dataset.load);if(!saved.ok || saved.revision==='empty')throw Error('Сначала сохраните план.');revision=saved.revision;
 if(!window.confirm('Включить сохранённый план на роутере? Несохранённые правки не применятся. Проверьте дату, время, режим и мелодии. Звонки будут звучать автоматически, пока не включён Mute.'))return;}
 var result=await request(root.dataset.automatic,{enabled:String(enabled),revision:revision});if(!result.ok)throw Error(result.code==='missing_media'?'Сначала загрузите пользовательские мелодии, выбранные во включённых строках расписаний.':'Не удалось применить. Проверьте сохранение, конфликты времён и хранилище.');
 sample=null;message.textContent='Запрос принят. Ожидаем подтверждения службы…';
 }catch(e){feedback=(e.message || 'Ответ потерян. Проверьте состояние перед повтором.')+' ';message.textContent=feedback;}finally{busy=false;on.disabled=false;off.disabled=false;setTimeout(refresh,1500);}}
on.addEventListener('click',function(){change(true);});off.addEventListener('click',function(){change(false);});
refresh();setInterval(refresh,5000);setInterval(draw,1000);document.addEventListener('visibilitychange',refresh);
}());
