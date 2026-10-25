// DOM/event fixture for real editor + activation scripts; no router or audio.
const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const root=path.resolve(__dirname,'..'),ui=path.join(root,'packages/schoolbell/router-page/root/www/schoolbell-test');
const clone=x=>JSON.parse(JSON.stringify(x));
function fixture(){
 const all=[],ids=new Map(),listeners={},intervals=[];
 class Element{
  constructor(tag='div'){this.tag=tag;this.children=[];this.dataset={};this.style={};this.events={};this.disabled=false;this._value='';this.textContent='';this.files=[];all.push(this);}
  appendChild(e){this.children.push(e);e.parent=this;return e;}
  replaceChildren(...e){this.children.forEach(c=>c.detached=true);this.children=[];e.forEach(c=>this.appendChild(c));}
  get options(){return this.children;}
  get selectedIndex(){return this.children.findIndex(c=>c.value===this.value);}
  get value(){return this._value || (this.tag==='select' && this.children[0]?this.children[0].value:'');}set value(v){this._value=String(v);}
  setAttribute(k,v){this[k]=String(v);}
  addEventListener(k,f){(this.events[k]??=[]).push(f);}
  async fire(k,e={}){for(const f of this.events[k]||[])await f(Object.assign({target:this,preventDefault(){}},e));}
  click(){if(this.disabled)return Promise.resolve();return this.fire('click');}
  focus(){}select(){}scrollIntoView(){}
  querySelector(s){return this.children.find(x=>s==='[value="annual"]' && x.value==='annual') || new Element();}
 }
 const html=fs.readFileSync(path.join(root,'packages/schoolbell/router-page/root/usr/lib/lua/luci/view/schoolbell_test.htm'),'utf8');
 for(const match of html.matchAll(/<(\w+)\b[^>]*\bid="([^"]+)"[^>]*>/g))ids.set(match[2],new Element(match[1]));
 const get=id=>{assert(ids.has(id),'missing DOM id '+id);return ids.get(id);};
 const window={addEventListener(k,f){(listeners[k]??=[]).push(f);},dispatchEvent(e){for(const f of listeners[e.type]||[])f(e);},confirm(){x.confirms++;return x.confirm;}};
 get('schedule-editor').dataset={load:'load',save:'save',preview:'preview',automatic:'auto',token:'test'};
 const document={hidden:false,getElementById:get,createElement:t=>new Element(t),addEventListener(){},querySelectorAll(s){return s==='.calendar-day'?all.filter(e=>!e.detached && (e.className||'').split(' ').includes('calendar-day')):[];}};
 let draft={mode:'annual',fixed_schedule:'quiet',manual_media:'test',pre_media:'test',pre_minutes:2,schedules:[{id:'s',name:'Normal',color:1,rows:[{id:'r',time:'08:00',media:'test',enabled:true,pre:false}]}],plans:[{year:2026,schedule_ids:['s'],days:'A'+'.'.repeat(364)}]};
 const x={get,window,confirms:0,confirm:true,posts:[],previews:[],rev:'r1',data:draft,active:{state:'disabled',enabled:false},clock:0};
 const fetch=async(url,options={})=>{
  const post=options.method==='POST',body=post?Object.fromEntries(options.body):{};let value;
  if(url==='load'){if(x.pauseLoad)await new Promise(resolve=>x.releaseLoad=resolve);if(x.failLoad)throw Error('network');value={ok:true,data:clone(x.data),revision:x.rev};}
  else if(url==='save'){x.data=JSON.parse(body.draft);x.rev='r2';value={ok:true,data:clone(x.data),revision:x.rev};}
  else if(url==='preview'){x.previews.push(JSON.parse(body.draft));value={ok:true,date:body.date,selected_schedule:'s',events:[]};}
  else if(url==='auto'){if(post){x.posts.push(body);value=x.reject?{ok:false,code:'conflict'}:{ok:true};}else value=x.active;}
  else throw Error('unexpected URL');return {ok:true,json:async()=>clone(value)};
 };
 window.schoolbellClockCommand=async body=>{assert(body.action==='enable');x.posts.push(body);if(x.reject)throw Error('clock_untrusted');return {ok:true};};
 const ctx={window,document,fetch,performance:{now:()=>x.clock},Date,Math,Number,String,Array,JSON,URLSearchParams,AbortController,CustomEvent:class{constructor(type,o={}){this.type=type;this.detail=o.detail;}},setTimeout:()=>1,clearTimeout(){},setInterval:f=>intervals.push(f)};
 vm.createContext(ctx);for(const file of ['automatic.js','schedules.js'])vm.runInContext(fs.readFileSync(path.join(ui,file),'utf8'),ctx);
 x.tick=async()=>{for(let i=0;i<6;i++)await Promise.resolve();};x.poll=async()=>{for(const f of intervals)await f();await x.tick();};
 x.day=()=>all.filter(e=>e.dataset.date==='2026-01-01' && !e.detached).at(-1);
 x.brush=name=>get('plan-legend').children.find(e=>e.textContent===name);
 return x;
}
(async()=>{
 let x=fixture();await x.tick();x.get('plan-year').value=2026;await x.get('year-show').click();
 assert(x.brush('Просмотр дня')['aria-pressed']==='true');
 await x.day().fire('pointerdown',{pointerType:'mouse',button:0});await x.day().click();await x.tick();
 assert(x.previews.length===1 && x.previews[0].plans[0].days[0]==='A');assert(!x.window.schoolbellEditor.snapshot().dirty);
 assert(x.get('preview-status').textContent.startsWith('Черновик'));console.log('PASS view date does not mutate; preview explicitly draft');
 await x.brush('Тихий день / ластик').click();await x.day().click();assert(x.window.schoolbellEditor.snapshot().dirty);assert(x.get('automatic-enable').disabled);
 await x.get('automatic-enable').fire('click');assert(!x.posts.length && !x.confirms);
 await x.get('workflow-save').click();await x.tick();assert(x.data.plans[0].days[0]==='.');assert(!x.posts.length);assert(!x.get('automatic-enable').disabled);
 console.log('PASS explicit erase, dirty gate, shared save never activates');
 x.active={state:'running',revision:'r1',mode:'annual'};await x.poll();assert(x.get('workflow-difference').textContent.includes('отличается'));
 x.pauseLoad=true;const applying=x.get('automatic-enable').click();await x.tick();assert(x.get('schedule-fields').disabled && x.get('manual-media').disabled);x.rev='other';x.releaseLoad();await applying;await x.tick();
 assert(!x.posts.length && !x.confirms && !x.get('schedule-fields').disabled);assert(x.get('automatic-status').textContent.includes('другом окне'));
 console.log('PASS active differs, frozen editor during apply, concurrent revision rejected');
 x=fixture();await x.tick();await x.get('automatic-enable').click();await x.tick();assert(x.confirms===1 && x.posts.length===1 && x.posts[0].revision==='r1');assert(x.get('workflow-active').textContent.includes('неизвестно'));
 x.active={state:'running',revision:'r1',mode:'annual'};await x.poll();assert(x.get('workflow-difference').textContent.includes('соответствует'));
 x.clock=16000;await x.poll(); // poll refreshes; force only draw below via editor event
 x.clock=32000;x.window.dispatchEvent({type:'schoolbell-editor-state'});assert(x.get('workflow-active').textContent.includes('неизвестно'));
 x.active={state:'waiting',enabled:false,revision:'r1'};await x.poll();assert(x.get('workflow-active').textContent.includes('выключены'));
 console.log('PASS explicit apply, wait for service confirmation, stale status not active');
 for(const flag of ['confirm','failLoad','reject']){x=fixture();await x.tick();x[flag]=flag==='confirm'?false:true;await x.get('automatic-enable').click();await x.tick();assert(!x.get('schedule-fields').disabled);if(flag!=='reject')assert(!x.posts.length);}
 x=fixture();await x.tick();x.get('schedule-name').value='Edited';await x.get('schedule-name').fire('input');await x.get('automatic-disable').click();await x.tick();assert(x.posts[0].enabled==='false');
 console.log('PASS cancel/read/POST failures unlock; disable allowed with unsaved changes');
})().catch(e=>{console.error(e);process.exitCode=1;});
