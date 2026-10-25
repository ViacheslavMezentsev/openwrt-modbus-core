local C=require('schoolbell.media_codec')
local Manager=require('schoolbell.media_manager')
local M={root='/etc/modbus-schoolbell/data',slots={'test','0','1','2','3','4','user1','user2','user3','user4','user5'},sizes={test=13104,['0']=41273,['1']=63321,['2']=69904,['3']=68023,['4']=82368}}
function M.editable(id)return type(id)=='string' and id:match('^user[1-5]$')~=nil end
function M.valid(id)return type(id)=='string' and (M.sizes[id]~=nil or M.editable(id))end
function M.open(fs,root,owned)
 local manager=Manager.new(fs,{ownership_safe=owned});local api={}
 local function read()
  local state=manager.recover();assert(state.state=='ready' or state.state=='empty','recovery_required')
  local catalog=state.state=='ready' and C.decode(fs.read('snapshots/'..state.pointer.current.snapshot..'/catalog.json',16384)) or {melodies=C.decode('[]')}
  return state,catalog
 end
 function api.list()
  local state,cat=read();local slots={}
  for _,id in ipairs(M.slots)do
   local v={id=id,name=M.editable(id) and 'Свободная позиция' or id..'.mp3',source=M.editable(id) and 'empty' or 'bundled',size_bytes=M.sizes[id] or 0}
   for _,m in ipairs(cat.melodies)do if m.id==id then assert(M.editable(id),'bundled override prohibited');local rev=m.revisions[1];v={id=id,name=m.name,source='user',size_bytes=rev.size_bytes,revision=rev.revision,audio=rev.audio}end end
   slots[#slots+1]=v
  end
  local free,capacity=fs.space();local bytes=0
  for _,h in ipairs(fs.list('objects'))do bytes=bytes+assert(fs.stat('objects/'..h)).size end
  local staging=fs.stat('upload.part');if staging then bytes=bytes+staging.size end
  for _,name in ipairs(fs.list('staging'))do if name:sub(-5)=='.part'then bytes=bytes+assert(fs.stat('staging/'..name)).size end end
  return {ok=true,generation=state.generation or 0,operation_id=state.operation_id,slots=slots,
   storage={total_kib=math.floor(capacity/1024),free_kib=math.floor(free/1024),used_kib=math.ceil(math.max(0,capacity-free)/1024),reserve_kib=math.ceil(math.max(524288,capacity/10)/1024),media_kib=math.ceil(bytes/1024),media_limit_kib=2048}}
 end
 function api.resolve(id)
  assert(M.valid(id),'slot');local list=api.list()
  for _,v in ipairs(list.slots)do if v.id==id then assert(v.source~='empty','missing media');return v.source=='user' and root..'/objects/'..v.revision or '/usr/share/schoolbell-sound-test/'..id..'.mp3',v end end
 end
 function api.replace(id,name,expected,op,source,audio)
  assert(M.editable(id) and type(name)=='string' and #name>0 and #name<=96 and not name:find('[%c]'),'name')
  local state,cat=read();if expected~=(state.generation or 0)then return {status='conflict'}end
  -- Any unreferenced leftovers are removed only with exclusive ownership.
  if state.state=='ready' then assert(manager.cleanup().status=='cleaned','cleanup')end
  local st=assert(fs.stat('upload.part'));assert(st.size>0 and st.size<=524288,'size')
  local hash=fs.hash('upload.part');local revision={revision=hash,source='user',size_bytes=st.size,audio=audio}
  local replacement={id=id,name=name,revisions={revision}};local found=false
  for i,m in ipairs(cat.melodies)do if m.id==id then cat.melodies[i]=replacement;found=true end end
  if not found then cat.melodies[#cat.melodies+1]=replacement end
  -- This library holds media overrides only; editor/active plans are not migrated.
  local docs={['catalog.json']=C.encode(cat),['settings.json']='{"scope":"engineering-media-overrides"}',
   ['schedules.json']='{"references":[]}',['plans.json']='{"references":[]}'}
  local free,capacity=fs.space();assert(free>=st.size+65536+math.max(524288,math.ceil(capacity/10)),'space reserve')
  local total=st.size;for _,h in ipairs(fs.list('objects'))do total=total+assert(fs.stat('objects/'..h)).size end
  if not fs.stat('objects/'..hash)then total=total+st.size end;assert(total<=2097152,'media quota')
  local result=manager.commit(op,expected,docs,{[hash]=source},state.state=='empty')
  if result.status=='saved' then result.revision=hash;result.cleanup=manager.cleanup().status end
  return result
 end
 function api.lookup(op)return manager.lookup(op)end
 function api.close()manager.close()end
 return api
end
return M
