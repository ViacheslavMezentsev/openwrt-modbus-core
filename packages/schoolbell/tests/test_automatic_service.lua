-- Execute the actual infinite worker with injected host clock/storage/player I/O.
local C=require('schoolbell.media_codec');local Store=require('schoolbell.automatic_store')
local Sound=dofile('packages/schoolbell/router-page/root/usr/lib/lua/schoolbell/sound_test.lua')
local realopen,realtime=io.open,os.time
local native=os.getenv('SCHOOLBELL_CHILD')=='1' and require('nixio') or nil
local t=assert(os.time({year=2026,month=10,day=25,hour=8,min=0,sec=0}))
local function scenario(name,opts)
 local now,up=t-1,100;local plays,claims,checkpoints=0,0,0;local raw,status,last;local active={enabled=true,generation=1,watermark=t-1,boot='boot',zone='UTC',revision='r',plan={}}
 local function publish()local body=C.encode(active);raw=C.encode({data=active,checksum=C.sha(body)})end;publish()
 local fakeClaim=function()end
 local fake={root='/unused',environment=function()return {now=now,date='2026-10-25',boot=opts.reboot and 'newboot' or 'boot',zone='UTC'}end,
 raw=function()return raw end,decode=function()return active end,
 claim=fakeClaim,advance=function()end,transaction=function(operation,generation,utc)
  if operation~=fakeClaim then checkpoints=checkpoints+1;active.watermark=math.max(active.watermark,utc);publish();return {ok=true,state=active,raw=raw}end
  claims=claims+1;if opts.fail then return {ok=false}end
  assert(generation==1 and utc==t);active.watermark=now;publish();return {ok=true,state=active,raw=raw}
 end}
 local originalEvents=require('schoolbell.automatic').events
 require('schoolbell.automatic').events=function()return opts.idle and {} or {{utc=t,media='test'}}end
 package.loaded['schoolbell.automatic_store']=fake
 package.loaded['schoolbell.controls']={snapshot=function()return {ok=true,muted=opts.muted or false}end}
 package.loaded['schoolbell.journal']={request=function()return {ok=true}end}
 package.loaded['schoolbell.sound_test']={system=function()return {muted=function()return false end,ready=function()return true end,acquire=function()return not opts.busy end,release=function()return true end,spawn=function()plays=plays+1;if native then local pid=native.fork();if pid==0 then native.exec('/bin/sleep','1');os.exit(127)end;return pid end;return 42 end,wait=function(pid)if native then return native.waitpid(pid,'nohang')end;return 42,'exited',0 end,sleep=function()if native then native.nanosleep(0,100000000)end end,kill=function(pid)if native then return native.kill(pid,9)end;error('unexpected kill')end}end,run=Sound.run}
 local rounds=0
 package.loaded['nixio']={open=function()return {lock=function()return true end}end,nanosleep=function()
  rounds=rounds+1;if rounds>=4 then error('finished fixture')end
  now=opts.jump and t+60+rounds or t-1+rounds*(opts.slow and 4 or 1);up=100+rounds*(opts.slow and 4 or 1)
 end}
 package.loaded['nixio.fs']={rename=function()last=status;return true end}
 os.time=function()return now end
 io.open=function(path,mode)
  if path=='/proc/uptime'then return {read=function()return tostring(up)..' 0' end,close=function()return true end}end
  if path=='/tmp/schoolbell-auto-status.next'then return {write=function(_,v)status=assert(C.decode(v));return true end,close=function()return true end}end
  error('unexpected file '..path..' '..tostring(mode))
 end
 local ok,err=pcall(dofile,'packages/schoolbell/router-page/root/usr/sbin/schoolbell-auto')
 assert(not ok and tostring(err):find('finished fixture'),tostring(err))
 io.open=realopen;os.time=realtime;require('schoolbell.automatic').events=originalEvents
 assert(plays==(opts.expected or 0),name..' plays '..plays)
 assert(claims==((opts.reboot or opts.idle) and 0 or 1),name..' claims '..claims)
 if opts.idle then assert(checkpoints==(opts.jump and 2 or 1),name..' repeated flash writes '..checkpoints)end
 assert(last and last.state~='executor_error',name..' executor error')
 print('PASS worker '..name)
end
scenario('normal once, durable before spawn',{expected=1})
scenario('mute never plays',{muted=true})
scenario('busy never requeues',{busy=true})
scenario('claim failure never plays',{fail=true})
scenario('forward jump never plays',{jump=true})
scenario('reboot requires confirmation',{reboot=true})
scenario('slow idle loops never recursively checkpoint',{idle=true,slow=true})
scenario('forward wall-clock jump checkpoints once',{idle=true,jump=true})
package.loaded['schoolbell.automatic_store']=Store
