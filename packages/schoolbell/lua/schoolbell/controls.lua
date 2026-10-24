-- Persistent mute state. Atomic publication; generation cancels an existing child.
local C=require('schoolbell.media_codec')
local M={root='/etc/schoolbell-editor'}
function M.decode(raw)
 if raw==nil then return {muted=false,generation=0}end
 local v=C.decode(raw)
 assert(v and type(v.muted)=='boolean' and C.integer(v.generation,0,2147483647),'mute state')
 return v
end
function M.read()
 local f=io.open(M.root..'/sound-control.json','rb')
 if not f then
  local fs=require('nixio.fs');assert(not fs.lstat(M.root..'/sound-control.json'),'unreadable mute state')
  assert(fs.lstat(M.root),'missing settings');return M.decode(nil)
 end
 local raw=f:read(513);f:close();assert(raw and #raw<=512,'mute size');return M.decode(raw)
end
function M.snapshot()
 -- Reader observes one atomically renamed file; no writer lock or writes.
 local ok,state=pcall(M.read)
 if not ok then return {ok=false,code='control_unreadable'}end
 return {ok=true,muted=state.muted,generation=state.generation}
end
function M.request(value,host)
 local fs;local ok,out=pcall(function()
  fs=require('schoolbell.media_fs').new(M.root,host)
  local state=M.decode(fs.read('sound-control.json',512))
  if value~=nil then
   assert(type(value)=='boolean','mute value')
   if state.muted~=value then
    assert(state.generation<2147483647,'generation exhausted')
    state={muted=value,generation=state.generation+1}
    if fs.stat('sound-control-next.json')then fs.unlink('sound-control-next.json')end
    fs.write('sound-control-next.json',C.encode(state));fs.sync('sound-control-next.json')
    fs.rename('sound-control-next.json','sound-control.json');fs.sync('')
   end
  end
  return {ok=true,muted=state.muted,generation=state.generation}
 end)
 local closed=true;if fs then closed=pcall(fs.close)end
 if not ok or not closed then return {ok=false,code='control_uncertain'}end
 return out
end
return M
