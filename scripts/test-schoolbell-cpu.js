const assert=require('node:assert/strict');const {percent,tone}=require('../packages/schoolbell/router-page/root/www/schoolbell-test/cpu.js');
const a={available:true,boot:'a',total:'1000',idle:'500'};const b={available:true,boot:'a',total:'1200',idle:'550'};
assert.equal(percent(a,b),75);assert.equal(tone(75),'success');assert.equal(tone(75.1),'warning');assert.equal(tone(90),'warning');assert.equal(tone(90.1),'danger');assert.equal(tone(null),'unknown');
assert.equal(percent(null,b),null);assert.equal(percent(a,{...b,boot:'b'}),null);assert.equal(percent(a,a),null);assert.equal(percent(a,{...b,idle:'900'}),null);assert.equal(percent(b,a),null);
console.log('PASS CPU delta, boot change, invalid counters and exact 75/90 thresholds');

const fs=require('node:fs'),vm=require('node:vm');let now=0,tick,listener;const attrs={};const bar={dataset:{},style:{setProperty(k,v){attrs[k]=v;}},setAttribute(k,v){attrs[k]=v;},removeAttribute(k){delete attrs[k];}},label={};const win={addEventListener(n,f){listener=f;}};
vm.runInNewContext(fs.readFileSync('packages/schoolbell/router-page/root/www/schoolbell-test/cpu.js','utf8'),{window:win,document:{getElementById:id=>id==='cpu-line'?bar:label},performance:{now:()=>now},setInterval:f=>{tick=f;}});
assert.equal(bar.dataset.tone,'unknown');listener({detail:a});assert.equal(bar.dataset.tone,'unknown');listener({detail:b});assert.equal(bar.dataset.tone,'success');assert.equal(attrs['aria-valuenow'],75);now=15001;tick();assert.equal(bar.dataset.tone,'unknown');assert.equal(attrs['aria-valuenow'],undefined);listener({detail:{...b,total:'1300',idle:'555'}});assert.equal(bar.dataset.tone,'danger');win.schoolbellSessionBlocked=true;tick();assert.equal(bar.dataset.tone,'unknown');
console.log('PASS CPU UI: first sample, stale age, invalid state and logout cannot show false zero');
