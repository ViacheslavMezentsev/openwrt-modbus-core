-- Synthetic JSON codec and virtual files isolate the real daemon loop.
-- Parsing malformed JSON and real filesystem failures are outside this fixture.
package.path='pkg/usr/lib/modbus/?.lua;'..package.path
local encode=require('json').encode
local function copy(v)
 if type(v)~='table' then return v end
 local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local base='/tmp/modbus/'
local daemon_path = arg[1] or 'pkg-demo/usr/bin/modbus-demo'
local function run(name, initial, phases, expected, race, unstable)
 local fs, known={}, {}
 local function stringify(t) local s=encode(t); known[s]=copy(t); return s end
 local function parse(s) return copy(known[s]) end
 local function journal(key, seqs)
  if seqs==false then fs[base..key]=nil; return end
  local lines={}; for _,n in ipairs(seqs or {}) do lines[#lines+1]=stringify({seq=n,kind='fixture',ts=n}) end
  fs[base..key]=table.concat(lines,'\n')..(#lines>0 and '\n' or '')
 end
 local function apply(p)
  journal('events-core.jsonl',p.active)
  journal('events-core.jsonl.1',p.archive)
  if p.partial then fs[base..'events-core.jsonl']=fs[base..'events-core.jsonl']:sub(1,-2) end
 end
 if initial~=nil then fs[base..'demo-state.json']=stringify({last_seq=initial}) end
 apply(phases[1])
 local step, active_opens=1,0
 local mockio={open=function(path,mode)
  assert(path:sub(1,#base)==base,'unexpected path')
  if mode=='r' then
   if path==base..'events-core.jsonl' then
    active_opens=active_opens+1
    if phases[step].unreadable then return nil, 'Permission denied', 13 end
    if race and active_opens==1 then apply(race) end
    if unstable and step==1 then journal('events-core.jsonl',{10+active_opens}) end
   end
   local content=fs[path]; if not content then return nil, "No such file", 2 end
   local f={read=function() return content end, close=function() return true end}
   f.lines=function()
    local pos=1
    return function()
     if pos>#content then return nil end
     local last=content:find('\n',pos,true) or (#content+1)
     local line=content:sub(pos,last-1); pos=last+1; return line
    end
   end
   return f
  end
  assert(mode=='w'); fs[path]=''
  return {write=function(_,s) fs[path]=fs[path]..s; return true end,close=function() return true end}
 end}
 local stop={}
 local env=setmetatable({io=mockio,os={
  time=function() return 1000+step end,
  rename=function(a,b) fs[b]=fs[a]; fs[a]=nil; return true end,
  execute=function(cmd)
   assert(cmd=='sleep 2')
   local state=parse(fs[base..'demo-status.json'])

   local e=expected[step]
   assert(state.last_seq==e[1] and state.processed_events==e[2],name..' unexpected result')
   assert(state.missed_events==(e[3] or 0),name..' gaps')
   assert(state.sequence_resets==(e[4] or 0),name..' resets')
   assert(state.read_errors==(e[5] or 0),name..' read errors')
   assert(state.status==(e[6] or 'running'),name..' status')
   if state.status=='read_error' then
    assert(state.read_error, 'missing diagnostic')
    if unstable then assert(active_opens==6, 'retry bound not respected') end
   end
   assert((parse(fs[base..'demo-state.json']) or {last_seq=0}).last_seq==e[1])
   step=step+1
   if not phases[step] then error(stop) end
   apply(phases[step]); return 0
  end},require=function(name)
   assert(name=='luci.jsonc'); return {parse=parse,stringify=stringify}
  end},{__index=_G})
 local chunk=assert(loadfile(daemon_path)); setfenv(chunk,env)
 local ok,err=pcall(chunk); assert(not ok and err==stop,tostring(err))
end
-- TC-37: ТЗ 4.4.8–4.4.10. Execute the real daemon with controlled I/O.
run('repeat',10,{{active={11,12}},{active={11,12}},{active={11,12,13}}},{{12,2},{12,2},{13,3}})
run('gap',10,{{archive={15},active={18,19}},{archive={15},active={18,19}}},{{19,3,6},{19,3,6}})
run('empty-then-reset',10,{{active=false,archive=false},{active={1,2}},{active={1,2,3}}},{{10,0},{2,2,0,1},{3,3,0,1}})
run('reset-with-gap',10,{{active={3,5}}},{{5,2,3,1}})
run('overlap',10,{{archive={11,12},active={12,13}},{archive={11,12},active={12,13}}},{{13,3},{13,3}})
run('fresh-start',nil,{{active={1,2}},{active={1,2,3}}},{{2,0},{3,1}})
run('empty-start',nil,{{active=false},{active={1,2}}},{{0,0},{2,2}})
-- TC-38: ТЗ 4.4.11. Rotation between segment opens, bounded retries, partial tail.
run('rotation-race',10,{{archive={9,10},active={11,12}}},{{13,3}},{archive={11,12},active={13}})
run('unstable',10,{{active={11}},{active={11,12}}},{{10,0,0,0,1,'read_error'},{12,2,0,0,1}},nil,true)
run('unstable-start',nil,{{active={11}},{active={11,12}},{active={11,12,13}}},{{0,0,0,0,1,'read_error'},{12,0,0,0,1},{13,1,0,0,1}},nil,true)
run('partial-tail',10,{{active={11,12},partial=true},{active={11,12}}},{{11,1},{12,2}})
run('open-error',10,{{active={11},unreadable=true},{active={11}}},{{10,0,0,0,1,'read_error'},{11,1,0,0,1}})
print('[test_demo] OK: resets, gaps, deduplication, tail start, rotation, bounded retries and partial records')
