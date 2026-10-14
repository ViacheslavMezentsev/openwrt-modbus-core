-- Core TC-130: fault injection on the actual reader, no filesystem fallback.
package.path="./pkg/usr/lib/?.lua;"..package.path
local adapter=require("modbus.profile_reader")
local loader=require("modbus.device_profiles")
local count=0
local function test(name,fn) fn();count=count+1;print("[profile-reader] OK "..name) end
local function clone(t) local o={};for k,v in pairs(t) do o[k]=v end;return o end
local function fixture(change)
    local text='{"id":"p","read_ranges":[{"function":3,"start":0,"count":1}]}'
    local state={fds={},closed=0,reads=0,opens=0,text=text}
    local function info(kind,ino)
        return {type=kind,ino=ino,dev=1,uid=0,gid=0,modedec=kind=="dir" and 755 or 644,
            modestr=kind=="dir" and "rwxr-xr-x" or "rw-r--r--",nlink=kind=="dir" and 2 or 1,
            size=#state.text,mtime=1,ctime=1}
    end
    local paths={["/"]=info("dir",1),["/proc/self/fd/1/catalogue"]=info("dir",2),
                 ["/proc/self/fd/2/p.json"]=info("reg",3)}
    state.paths=paths
    local api={uname=function() return {sysname="Linux",machine="x86_64"} end,
        open_flags=function(a,b) assert(a=="rdonly" and b=="nonblock");return 2048 end}
    api.fs={lstat=function(path)
        if state.onstat then state.onstat(path) end
        return paths[path] and clone(paths[path])
    end}
    api.open=function(path,flags)
        state.opens=state.opens+1
        assert(flags==2048+131072+524288+(path:match("json$") and 0 or 65536))
        if state.onopen then state.onopen(path) end
        if state.open_fail==state.opens then return nil end
        local n=state.opens
        local fd={info=clone(paths[path]),pos=1}
        state.fds[#state.fds+1]=fd
        function fd:fileno() return n end
        function fd:stat()
            if state.onfstat then state.onfstat(self,n) end
            return clone(self.info)
        end
        function fd:read(size)
            state.reads=state.reads+1
            assert(size>0 and size<=2048)
            if state.onread then state.onread(self) end
            if state.read_error then return nil end
            if state.read_throw then error("injected") end
            local part=state.text:sub(self.pos,self.pos+math.min(size,state.chunk or size)-1)
            self.pos=self.pos+#part;return part
        end
        function fd:close()
            assert(not self.closed);self.closed=true;state.closed=state.closed+1
            if state.close_throw then error("close") end
            return not state.close_fail
        end
        return fd
    end
    if change then change(state,api) end
    local reader,err=adapter.new(api,"/catalogue")
    return reader,state,err,api
end
local function run(change,code)
    local reader,s=fixture(change)
    local text,err=reader("p",16385)
    assert(not text and err.code==code,err and err.code)
    assert(s.closed==#s.fds,"descriptor leak")
    return s
end
test("valid short reads and complete cleanup",function()
    local read,s=fixture(function(s) s.chunk=3 end)
    assert(read("p",16385)==s.text and s.reads>2 and s.closed==3)
end)
test("arguments rejected before I/O",function()
    for _,id in ipairs({"../p","P","p.json","","a/b",string.rep("p",33)}) do
        local read,s=fixture();local v,e=read(id,16385)
        assert(not v and e.code=="argument" and s.opens==0)
    end
    local read,s=fixture();assert(not read("p",16384));assert(s.opens==0)
end)
test("unsupported platform and malformed roots",function()
    local read,_,e=fixture(function(_,a) a.uname=function() return {sysname="Linux",machine="arm"} end end)
    assert(not read and e.code=="platform")
    local _,_,_,a=fixture()
    for _,root in ipairs({"relative","/a/../b","/a//b","/a/","/a/./b","/a"..string.char(0)}) do
        local v,err=adapter.new(a,root);assert(not v and err.code=="path")
    end
end)
test("owner modes and symlinks rejected on every component",function()
    for _,path in ipairs({"/","/proc/self/fd/1/catalogue","/proc/self/fd/2/p.json"}) do
        for _,field in ipairs({"uid","modestr","type"}) do
            run(function(s)
                s.paths[path][field]=field=="uid" and 1000 or field=="type" and "lnk" or "rwxrwxrwx"
            end,"trust")
        end
    end
end)
test("FIFO directory device and hardlink profile rejected before open",function()
    for _,kind in ipairs({"fifo","dir","chr","sock"}) do
        local s=run(function(s) s.paths["/proc/self/fd/2/p.json"].type=kind end,"trust")
        assert(s.opens==2 and s.reads==0)
    end
    run(function(s) s.paths["/proc/self/fd/2/p.json"].nlink=2 end,"file")
end)
test("open failures close prior descriptors",function()
    for i=1,3 do run(function(s) s.open_fail=i end,"open") end
end)
test("replacement between lstat and open rejected before read",function()
    local s=run(function(s)
        s.onopen=function(path) if path:match("json$") then s.paths[path].ino=99 end end
    end,"changed")
    assert(s.reads==0)
end)
test("read errors and exceptions close every descriptor",function()
    run(function(s) s.read_error=true end,"read")
    run(function(s) s.read_throw=true end,"io")
    run(function(s) s.onfstat=function() error("fstat") end end,"io")
    run(function(s) s.onstat=function(path) if path:match("json$") then error("lstat") end end end,"io")
end)
test("replacement after opening and ancestor changes rejected",function()
    run(function(s) s.onread=function() s.paths["/proc/self/fd/2/p.json"].ino=99 end end,"changed")
    run(function(s) s.onread=function() s.paths["/proc/self/fd/1/catalogue"].uid=1000 end end,"trust")
end)
test("file mutation metadata and short EOF rejected",function()
    run(function(s) s.onread=function(fd) fd.info.mtime=2 end end,"changed")
    run(function(s) s.text="" end,"changed")
end)
test("exact byte limit accepted and growth bounded",function()
    local read,s=fixture(function(s) s.text=string.rep(" ",16384);s.paths["/proc/self/fd/2/p.json"].size=16384 end)
    assert(#assert(read("p",16385))==16384 and s.closed==3)
    local s2=run(function(s) s.text=string.rep(" ",16385) end,"bytes")
    assert(s2.reads==9)
    run(function(s) s.paths["/proc/self/fd/2/p.json"].size=16385 end,"file")
end)
test("cleanup continues after close failure or exception",function()
    run(function(s) s.close_fail=true end,"close")
    run(function(s) s.close_throw=true end,"close")
end)
test("activation failure preserves previous snapshot",function()
    local read,s=fixture()
    local store=assert(loader.new(read))
    local old=assert(store:activate({d="p"},true,0))
    s.opens=0;s.paths["/proc/self/fd/2/p.json"].uid=1000
    assert(not store:activate({d="p"},true,0))
    assert(store:current()==old and old:profile("d"):id()=="p")
end)
print("[test_profile_reader] OK: "..count.." cases")
