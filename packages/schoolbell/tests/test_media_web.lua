package.path='packages/schoolbell/router-page/root/usr/lib/lua/?.lua;'..package.path
local L=require('schoolbell.media_library');local C=require('schoolbell.media_codec');local F=require('schoolbell.media_fs');local host=require('schoolbell.media_fs_host');L.root=assert(arg[1])
local enabled=false;local decoded=0;local decoder_ok=true
package.loaded['schoolbell.media_fs']={new=function(p)return F.new(p,host)end}
package.loaded.nixio={};package.loaded['nixio.fs']={mkdir=host.mkdir,rmdir=host.rmdir}
package.loaded['schoolbell.sound_test']={lock=L.root..'/gate',run=function()decoded=decoded+1;return decoder_ok and {ok=true} or {ok=false,state='failed'}end}
package.loaded['schoolbell.automatic_store']={raw=function()return '{}'end,decode=function()return {enabled=enabled}end}
local W=require('schoolbell.media_web');local f=assert(io.open('packages/schoolbell/media/test.mp3','rb'));local bytes=f:read('*a');f:close()
local reads=0;local function run(gen,op,data,disconnect)
 local at=1;return W.upload({id='user1',name='test.mp3',size=#bytes,generation=gen,operation=string.rep(op,32)},function()
  reads=reads+1;if disconnect then return nil,'lost' end
  if at>#data then return nil end;local s=data:sub(at,at+4095);at=at+#s;return s
 end)
end
enabled=true;assert(run(0,'a',bytes).code=='automatic_enabled' and reads==0 and decoded==0);enabled=false
assert(run(0,'a',bytes,true).code=='rejected' and decoded==0 and W.list().generation==0)
assert(run(0,'a',bytes:sub(1,-10)).code=='rejected' and decoded==0)
assert(run(0,'a',string.rep('x',#bytes)).code=='rejected' and decoded==0)
decoder_ok=false;assert(run(0,'a',bytes).code=='rejected' and W.list().generation==0);decoder_ok=true
local saved=run(0,'b',bytes);assert(saved.ok and W.list().generation==1 and W.lookup(string.rep('b',32)).state=='retained')
reads=0;assert(run(0,'c',bytes).code=='conflict' and reads==0)
local copied='';assert(W.sample('user1',function(s)copied=copied..s end).ok and copied==bytes)
assert(W.lookup(string.rep('d',32)).state=='unknown')
local plan={pre_media='test',schedules={{rows={{media='user5',enabled=true,pre=false}}}}}
assert(not W.plan_ready(plan));plan.schedules[1].rows[1].media='user1';assert(W.plan_ready(plan))
for i=2,5 do
 local at=1;local result=W.upload({id='user'..i,name='bell'..i..'.mp3',size=#bytes,generation=i-1,operation=string.rep(tostring(i),32)},function()if at>#bytes then return nil end;local b=bytes:sub(at,at+4095);at=at+#b;return b end);assert(result.ok)
end
assert(W.list().generation==5 and #W.list().slots==11)
plan.schedules[1].rows[1].media='user5';assert(W.plan_ready(plan))
local forbidden=W.upload({id='0',name='no.mp3',size=#bytes,generation=5,operation=string.rep('f',32)},function()error('protected file read')end);assert(forbidden.code=='invalid')
local S=require('schoolbell.schedule_store');local draft=S.empty();draft.schedules={{id='u',name='User',rows={{id='r',time='08:00',media='user5',enabled=true,pre=false}}}};assert(S.validate(C.encode(draft)))
assert(host.mkdir(L.root..'/gate'));assert(W.list().code=='busy');assert(host.rmdir(L.root..'/gate'))
print('PASS media gateway: disabled-auto, stream failure/bounds, invalid MP3, decoder refusal, CAS before read, lookup, preview, gate')
