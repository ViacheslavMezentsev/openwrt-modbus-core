-- Inactive editor draft. No player, scheduler, cron, UCI or core calls.
local J=require("modbus.json_strict")
local C=require("schoolbell.media_codec")
local Calendar=require("schoolbell.calendar")
local M={max_bytes=12288, file_bytes=16384}
local function array(n) return assert(J.decode(n or "[]")) end
local function fail(code,path) error({code=code,path=path},0) end
local function object(t,fields,path)
    if J.kind(t)~="object" then fail("object",path) end
    for k in pairs(t) do if not fields[k] then fail("unknown_field",path.."."..tostring(k)) end end
    for k in pairs(fields) do if t[k]==nil then fail("missing_field",path.."."..k) end end
end
function M.validate(text)
    if type(text)~="string" or #text>M.max_bytes then return nil,{code="size"} end
    local d,e=J.decode(text)
    if not d then return nil,{code="json",path=e.code} end
    local ok,why=pcall(function()
        object(d,{schedules=true,pre_minutes=true,pre_media=true},"draft")
        if J.kind(d.schedules)~="array" or #d.schedules>16 then fail("limit","schedules") end
        if d.pre_media~="test" then fail("media_reference","pre_media") end
        local schedules,total={},0
        for i,s in ipairs(d.schedules) do
            local path="schedules."..i
            object(s,{id=true,name=true,rows=true},path)
            if type(s.name)~="string" or #s.name<1 or #s.name>96
               or s.name:find("[%z\1-\31\127]") or not s.name:find("%S") then fail("name",path..".name") end
            if J.kind(s.rows)~="array" or #s.rows>32 then fail("limit",path..".rows") end
            total=total+#s.rows
            if total>128 then fail("limit","total_rows") end
            for j,row in ipairs(s.rows) do
                object(row,{id=true,time=true,media=true,enabled=true,pre=true},path..".rows."..j)
            end
            schedules[i]={id=s.id,rows=s.rows}
        end
        local valid,err=Calendar.validate({revision="editor",mode="annual",timezone="UTC",
            pre_minutes=d.pre_minutes,pre_media=d.pre_media,media={"test"},
            schedules=schedules,plans={}})
        if not valid then fail(err.code,err.path) end
    end)
    if not ok then return nil,type(why)=="table" and why or {code="invalid"} end
    local encoded=C.encode(d)
    if #encoded>M.max_bytes then return nil,{code="size"} end
    return d,encoded
end
function M.empty()
    return {schedules=array(),pre_minutes=2,pre_media="test"}
end
local function read(fs)
    local raw=fs.read("current.json",M.file_bytes)
    if not raw then
        -- Missing current with a previous checkpoint is never a fresh installation.
        if fs.stat("previous.json") then fail("recovery_required") end
        return {ok=true,revision="empty",data=M.empty(),active=false}
    end
    local saved=C.decode(raw)
    object(saved,{data=true,checksum=true},"checkpoint")
    local data,body=M.validate(C.encode(saved.data))
    if not data or not C.hex(saved.checksum,64) or C.sha(body)~=saved.checksum then fail("recovery_required") end
    return {ok=true,revision=saved.checksum,data=data,active=false},raw
end
function M.load(fs)
    local ok,result=pcall(read,fs)
    return ok and result or {ok=false,code="recovery_required"}
end
function M.save(fs,text,expected)
    local data,body=M.validate(text)
    if not data then return {ok=false,code="invalid",detail=body} end
    if type(expected)~="string" or (expected~="empty" and not C.hex(expected,64)) then
        return {ok=false,code="revision"}
    end
    local ok,result=pcall(function()
        local current,old=read(fs)
        if expected~=current.revision then return {ok=false,code="conflict"} end
        local digest=C.sha(body)
        if digest==current.revision then current.unchanged=true; return current end
        local raw=C.encode({data=data,checksum=digest})
        if #raw>M.file_bytes then fail("size") end
        -- Fixed transient names under the exclusive FS lock. Never promote leftovers.
        for _,name in ipairs({"next.json","previous-next.json"}) do
            if fs.stat(name) then fs.unlink(name) end
        end
        local free,total=fs.space()
        local reserve=math.max(524288,math.ceil(total/10))
        -- Existing current/previous are already included in free; allow two new files
        -- plus directory/allocation overhead. ENOSPC is still handled after this check.
        if free<reserve+2*M.file_bytes+16384 then fail("space") end
        fs.write("next.json",raw); fs.sync("next.json")
        if old then
            fs.write("previous-next.json",old); fs.sync("previous-next.json")
            fs.rename("previous-next.json","previous.json"); fs.sync("")
        end
        fs.rename("next.json","current.json"); fs.sync("")
        local after=read(fs)
        if after.revision~=digest then fail("recovery_required") end
        return after
    end)
    if ok then return result end
    local code=type(result)=="table" and result.code
    -- A write/rename/sync error may have happened after commit; require a fresh GET.
    return {ok=false,code=code or "storage_uncertain"}
end
function M.request(root,operation,text,expected,host)
    local FS=require("schoolbell.media_fs")
    local ok,fs=pcall(FS.new,root,host)
    if not ok then return {ok=false,code="storage_unavailable"} end
    local good,result=pcall(operation=="save" and M.save or M.load,fs,text,expected)
    local closed=pcall(fs.close)
    if not good or not closed then return {ok=false,code="storage_uncertain"} end
    return result
end
return M
