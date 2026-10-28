(function(global){
'use strict';
function percent(a,b){
 if(!a||!b||!a.available||!b.available||a.boot!==b.boot)return null;
 var total=Number(b.total)-Number(a.total),idle=Number(b.idle)-Number(a.idle);
 if(!Number.isSafeInteger(Number(b.total))||!Number.isSafeInteger(Number(b.idle))||total<=0||idle<0||idle>total)return null;
 return Math.round((total-idle)*1000/total)/10;
}
function tone(p){return p===null?'unknown':p>90?'danger':p>75?'warning':'success';}
if(typeof module==='object'&&module.exports){module.exports={percent:percent,tone:tone};return;}
var previous=null,value=null,at=0,bar=document.getElementById('cpu-line'),label=document.getElementById('cpu-value');
function draw(){var p=performance.now()-at>15000||global.schoolbellSessionBlocked?null:value;bar.dataset.tone=tone(p);bar.style.setProperty('--cpu-fill',(p===null?0:p)+'%');label.textContent=p===null?'CPU · нет измерения':'CPU · '+p.toFixed(1)+'%';if(p===null)bar.removeAttribute('aria-valuenow');else bar.setAttribute('aria-valuenow',p);}
global.addEventListener('schoolbell-system-metrics',function(e){value=percent(previous,e.detail);previous=e.detail;at=performance.now();draw();});
draw();setInterval(draw,1000);
})(typeof window==='object'?window:globalThis);
