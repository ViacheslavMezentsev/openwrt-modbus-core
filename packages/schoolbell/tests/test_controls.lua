local M=require('schoolbell.controls');local C=require('schoolbell.media_codec')
local files={};local writes=0
local fs={read=function(p)return files[p]end,stat=function(p)return files[p] and {}end,write=function(p,v)files[p]=v;writes=writes+1 end,sync=function()end,rename=function(a,b)files[b]=files[a];files[a]=nil end,unlink=function(p)files[p]=nil end,close=function()end}
local original=package.loaded['schoolbell.media_fs'];package.loaded['schoolbell.media_fs']={new=function()return fs end}
assert(M.request().muted==false and writes==0)
local on=M.request(true);assert(on.ok and on.muted and on.generation==1)
assert(M.request(true).generation==1 and writes==1)
local off=M.request(false);assert(off.ok and not off.muted and off.generation==2)
assert(M.decode(files['sound-control.json']).generation==2)
files['sound-control.json']='broken';assert(not M.request(false).ok)
package.loaded['schoolbell.media_fs']=original
local savedRead=M.read;M.read=function()return {muted=true,generation=7}end
package.loaded['schoolbell.media_fs']={new=function()error('writer lock busy')end}
assert(M.snapshot().muted and M.snapshot().generation==7)
M.read=function()error('corrupt')end;assert(M.snapshot().code=='control_unreadable')
M.read=savedRead;package.loaded['schoolbell.media_fs']=original
local S=require('schoolbell.schedule_store')
local d=S.empty();assert(d.mode=='fixed' and d.fixed_schedule=='quiet' and d.manual_media=='test')
d.schedules={{id='normal',name='Normal',rows={{id='r',time='08:00',media='1',pre=true,enabled=true}}}};d.fixed_schedule='normal';d.manual_media='4';d.pre_media='0'
local text=C.encode(d);assert(S.validate(text));local out=S.preview(text,'2026-10-25');assert(out.ok and #out.events==2 and out.events[1].media=='0' and out.events[2].media=='1')
d.mode='annual';d.plans=nil;out=S.preview(C.encode(d),'2026-10-25');assert(out.ok and #out.events==0)
d.manual_media='../evil';assert(not S.validate(C.encode(d)))
print('PASS controls: durable generation, idempotent mute, corrupt state, fixed/quiet/annual fallback, media whitelist')

local method,length,status,security='POST','2048',nil,0
package.loaded['luci.http']={getenv=function(k)if k=='REQUEST_METHOD'then return method elseif k=='CONTENT_LENGTH'then return length else return 'application/x-www-form-urlencoded'end end,status=function(v)status=v end,formvalue=function()error('must not parse')end}
package.loaded['luci.dispatcher']={test_post_security=function()security=security+1;return false end}
dofile('packages/schoolbell/router-page/root/usr/lib/lua/luci/controller/schoolbell_test.lua')
luci.controller.schoolbell_test.controls();assert(status==413 and security==0)
length='100';luci.controller.schoolbell_test.controls();assert(security==1)
method='PUT';luci.controller.schoolbell_test.controls();assert(status==405)
luci.controller.schoolbell_test.manual();assert(security==2)
print('PASS controls HTTP: bounds, method and CSRF before mutation/playback')
