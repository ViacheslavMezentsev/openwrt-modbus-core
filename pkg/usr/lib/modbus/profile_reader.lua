-- Core 6.9.1/6.9.7: Linux/nixio bounded trusted catalogue reader.
local M = {}
local ROOT = "/usr/share/modbus-rtu-core/profiles"
local function fail(code) error({code=code}, 0) end
local function trusted(s, kind)
    if type(s) ~= "table" or s.type ~= kind or s.uid ~= 0
        or type(s.modestr) ~= "string" or #s.modestr ~= 9
        or s.modestr:sub(5,5) ~= "-" or s.modestr:sub(8,8) ~= "-" then fail("trust") end
    if kind == "reg" and (s.nlink ~= 1 or type(s.size) ~= "number"
        or s.size < 0 or s.size > 16384) then fail("file") end
end
local function same(a,b,kind)
    trusted(b,kind)
    for _,key in ipairs({"dev","ino","uid","gid","modedec","nlink"}) do
        if a[key] == nil or b[key] ~= a[key] then fail("changed") end
    end
    if kind == "reg" then
        for _,key in ipairs({"size","mtime","ctime"}) do
            if a[key] == nil or b[key] ~= a[key] then fail("changed") end
        end
    end
end
-- Explicit dependency/path seam for host tests and trusted core code only.
function M.new(nixio, root)
    root = root or ROOT
    local ok, result = pcall(function()
        if type(root) ~= "string" or #root > 256 or root:sub(1,1) ~= "/"
            or root:sub(-1) == "/" or root:find("//",1,true) or root:find("%z") then fail("path") end
        local parts={}
        for part in root:gmatch("[^/]+") do
            if part == "." or part == ".." then fail("path") end
            parts[#parts+1]=part
        end
        if #parts > 16 then fail("path") end
        local u=nixio.uname()
        if u.sysname ~= "Linux" or (u.machine ~= "mips" and u.machine ~= "mipsel"
            and u.machine ~= "x86_64") then fail("platform") end
        -- Linux v4.14 asm-generic/fcntl.h; MIPS inherits these three constants.
        -- nixio 19.07 exposes nonblock symbolically, but not these flags.
        local flags=nixio.open_flags("rdonly","nonblock")+131072+524288
        local dirflags=flags+65536
        return function(id, maximum_bytes)
            if type(id) ~= "string" or #id < 1 or #id > 32
                or not id:match("^[a-z0-9][a-z0-9_-]*$") or maximum_bytes ~= 16385 then
                return nil,{code="argument"}
            end
            local opened={}
            local success, data=pcall(function()
                local function open(path,kind)
                    local before=nixio.fs.lstat(path)
                    trusted(before,kind)
                    local fd=nixio.open(path,kind=="dir" and dirflags or flags)
                    if not fd then fail("open") end
                    opened[#opened+1]={fd=fd,path=path,info=before,kind=kind}
                    same(before,fd:stat(),kind)
                    return fd
                end
                local parent=open("/","dir")
                for _,part in ipairs(parts) do
                    parent=open("/proc/self/fd/"..parent:fileno().."/"..part,"dir")
                end
                local fd=open("/proc/self/fd/"..parent:fileno().."/"..id..".json","reg")
                local chunks,total={},0
                while total < maximum_bytes do
                    local chunk=fd:read(math.min(2048,maximum_bytes-total))
                    if type(chunk) ~= "string" then fail("read") end
                    if #chunk == 0 then break end
                    if #chunk > math.min(2048,maximum_bytes-total) then fail("read_contract") end
                    total=total+#chunk
                    if total > 16384 then fail("bytes") end
                    chunks[#chunks+1]=chunk
                end
                for _,entry in ipairs(opened) do
                    same(entry.info,entry.fd:stat(),entry.kind)
                    same(entry.info,nixio.fs.lstat(entry.path),entry.kind)
                end
                if total ~= opened[#opened].info.size then fail("changed") end
                return table.concat(chunks)
            end)
            local closed=true
            for i=#opened,1,-1 do
                local call, status=pcall(opened[i].fd.close,opened[i].fd)
                if not call or not status then closed=false end
            end
            if not closed then return nil,{code="close"} end
            if not success then
                return nil,type(data)=="table" and data or {code="io"}
            end
            return data
        end
    end)
    if not ok then return nil,type(result)=="table" and result or {code="backend"} end
    return result
end
function M.system()
    local ok,nixio=pcall(require,"nixio")
    if not ok then return nil,{code="backend"} end
    local loaded,fs=pcall(require,"nixio.fs")
    if not loaded then return nil,{code="backend"} end
    -- Keep dependency injection local; do not modify the shared nixio module.
    return M.new({uname=nixio.uname,open_flags=nixio.open_flags,open=nixio.open,fs=fs})
end
return M
