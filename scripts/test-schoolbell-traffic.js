/* Schoolbell TC-160: passive request accounting with controlled monotonic clock. */
'use strict';
const assert=require('node:assert/strict');
const {create,observe}=require('../packages/schoolbell/router-page/root/www/schoolbell-test/traffic.js');
(async()=>{
 let now=0,m=create(()=>now);assert.equal(m.snapshot().items.length,12);
 const a=m.begin('GET');now=4999;const b=m.begin('POST');m.end(a,false);
 assert.equal(m.snapshot().items[11].reads,1);assert.equal(m.snapshot().items[11].commands,1);
 now=5000;m.end(b,true);assert.equal(m.snapshot().items[10].errors,1);
 assert.equal(m.snapshot().pending,0);m.end(b,true);assert.equal(m.snapshot().pending,0);
 now=60000;assert.equal(m.snapshot().items.reduce((n,x)=>n+x.reads+x.commands,0),0);
 const late=m.begin('HEAD');now=600000;m.end(late,false);
 assert.equal(m.snapshot().pending,0);assert.equal(m.snapshot().items.reduce((n,x)=>n+x.finished,0),0);
 for(let i=0;i<1000;i++){now+=5000;const t=m.begin('GET');m.end(t,false);assert.equal(m.snapshot().items.length,12);}
 now=0;m=create(()=>now);let calls=0;const reply={ok:true,json:()=>({ok:false,code:'busy'})};
 const options={method:'POST',signal:{},body:'secret'};
 const f=observe((input,opts)=>{calls++;assert.equal(input,'api');assert.equal(opts,options);now=125;return Promise.resolve(reply);},m,u=>u==='api');
 assert.equal(await f('api',options),reply);assert.equal(calls,1);assert.equal(m.snapshot().items[11].max,125);assert.equal(m.snapshot().items[11].errors,0);
 const error=new Error('aborted');const fail=observe(()=>Promise.reject(error),m,()=>true);
 await assert.rejects(fail('api'),e=>e===error);assert.equal(m.snapshot().pending,0);assert.equal(m.snapshot().items[11].errors,1);
 const sync=observe(()=>{throw error;},m,()=>true);assert.throws(()=>sync('api'),e=>e===error);assert.equal(m.snapshot().pending,0);
 const http=observe(()=>Promise.resolve({ok:false,status:403}),m,()=>true);await http('api');assert.equal(m.snapshot().items[11].errors,3);
 const before=JSON.stringify(m.snapshot());const passthrough=observe(()=>reply,m,()=>false);assert.equal(passthrough('audio'),reply);assert.equal(JSON.stringify(m.snapshot()),before);
 let resolve;const pending=observe(()=>new Promise(r=>resolve=r),m,()=>true);const p=pending('api');assert.equal(m.snapshot().pending,1);resolve(reply);await p;assert.equal(m.snapshot().pending,0);
 // Browser integration: all sections are observed even while Journal is hidden.
 const vm=require('node:vm');const fs=require('node:fs');let sent=0,tick;
 const elements={
  'traffic-chart':{replaceChildren(){},appendChild(){}},
  'schedule-editor':{dataset:{load:'/api/load',save:'/api/save',sample:'/api/audio',token:'secret'}},
  'session-panel':{dataset:{session:'/api/session'}},
  'backup-panel':{dataset:{url:'/api/backup'}},
  'router-form':{action:'http://device/api/play'},
  'panel-journal':{hidden:true},'traffic-mode':{},'traffic-scale':{},'traffic-stats':{}
 };
 const window={fetch:async()=>{sent++;return reply;}};
 const document={hidden:false,getElementById:id=>elements[id],createElementNS:()=>({setAttribute(){},appendChild(){}})};
 vm.runInNewContext(fs.readFileSync('packages/schoolbell/router-page/root/www/schoolbell-test/traffic.js','utf8'),{window,document,URL,Set,performance:{now:()=>now},location:{href:'http://device/page',origin:'http://device'},setInterval:f=>{tick=f;}});
 assert.equal(sent,0);
 await window.fetch('/api/load');await window.fetch('/api/save',{method:'POST'});
 await window.fetch('/api/backup?action=status');await window.fetch('/api/audio');await window.fetch('http://other/api/load');
 elements['panel-journal'].hidden=false;tick();
 assert.match(elements['traffic-stats'].textContent,/Чтение: 2 · Команды: 1/);
 assert.equal(sent,5);tick();assert.equal(sent,5);
const html=fs.readFileSync('out/site/schoolbell/index.html','utf8');
 assert.ok(html.indexOf('assets/demo.js')<html.indexOf('assets/traffic.js'));
 assert.ok(html.indexOf('assets/traffic.js')<html.indexOf('assets/session.js'));
 assert.ok(html.includes('id="traffic-chart"'));assert.ok(html.includes('не внутренние обмены исполнителя'));
 console.log('PASS traffic: 5s boundaries, 12-slot retention, late/duplicate completions, latency, HTTP/rejection/abort, pass-through, no retries, Pages order');
})().catch(e=>{console.error(e);process.exit(1);});
