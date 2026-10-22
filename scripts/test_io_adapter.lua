-- Core TC-134..138/140: injected single-call primitives, no real descriptors.
package.path="./pkg/usr/lib/?.lua;"..package.path
local m=require("modbus.io_adapter")
local count=0
local function test(n,f) f();count=count+1;print("[io-adapter] OK "..n) end
local function fails(f) assert(not pcall(f)) end
local function tok(op,attempt,connection) return {connection=connection or 1,operation=op or 1,attempt=attempt or 1} end
local cap={single_call=true,bounded_setup=true,bounded_close=true,rtu_tx_complete=true}
local cfg={kind="tcp",address="127.0.0.1",port=502}
local function fixture()
    local f={now=0,calls={},closed=0,wakes=0,drains=0}
    local sys={}
    for _,k in ipairs({"open","configure","connect","connect_status","write","read","tx_empty","close"}) do
        local name=k
        sys[name]=function(...)
            f.calls[#f.calls+1]=name
            if f[name] then return f[name](...) end
            if name=="open" then return 10
            elseif name=="write" then local _,b=...;return #b
            elseif name=="read" then return nil,"EAGAIN"
            elseif name=="close" then f.closed=f.closed+1 end
            return true
        end
    end
    sys.clock=function() return f.now end
    sys.poll=function(i,t) f.interests=i;f.timeout=t;if f.poll then return f.poll(i,t) end;return {} end
    sys.wake=function() f.wakes=f.wakes+1;return true end
    sys.drain_wake=function() f.drains=f.drains+1;return true end
    return m.new(sys,cap),f,sys
end
local function permit() return true end
local function ready(t) return {token=t or tok(),writable=true,readable=true,capacity=520} end
local function setup(a,kind)
    local c=kind=="rtu" and {kind="rtu",address="/fake/tty",baud=115200} or cfg
    assert(a:prepare("p",c,tok(),100))
    local out=a:service("p",permit)
    assert(out.event.kind=="prepared" and out.calls<=4)
end
local function send(a)
    a:transmit("p",tok(),"abcdefgh",100)
    local out=a:service("p",permit,ready());assert(out.event.count==8)
    assert(a:service("p",permit).event.kind=="tx_complete")
end
test("capability gate and copied configuration",function()
    local a,f,sys=fixture();local bad={single_call=false,bounded_setup=true,bounded_close=true,rtu_tx_complete=true}
    fails(function() m.new(sys,bad) end)
    bad.single_call=true;bad.rtu_tx_complete=false
    local b=m.new(sys,bad)
    assert(not b:prepare("p",{kind="rtu",address="/fake/tty",baud=115200},tok(),100))
    local c={kind="tcp",address="127.0.0.1",port=502};a:prepare("p",c,tok(),100);c.port=1
    f.connect=function(_,_,port) assert(port==502);return true end
    assert(a:service("p",permit).event.kind=="prepared")
end)
test("connect readiness requires SO_ERROR check",function()
    local a,f=fixture();f.connect=function() return nil,"EINPROGRESS" end
    a:prepare("p",cfg,tok(),100)
    assert(not a:service("p",permit).event)
    assert(a:service("p",permit).calls==0)
    f.connect_status=function() return nil,"ECONNREFUSED" end;f.now=1
    local out=a:service("p",permit,ready())
    assert(out.event.code=="ECONNREFUSED" and out.calls==1)
    assert(a:service("p",permit).event.kind=="closed" and f.closed==1)
    local b,g=fixture()
    g.connect=function() g.now=100;return nil,"EINPROGRESS" end
    b:prepare("p",cfg,tok(),100)
    assert(b:service("p",permit).event.code=="expired")
end)
test("expiry before write emits no bytes",function()
    local a,f=fixture();setup(a);a:transmit("p",tok(),"abc",100)
    f.now=100
    local out=a:service("p",permit,ready())
    assert(out.calls==0 and out.event.code=="expired" and not out.event.may_have_sent)
end)
test("permission callback time and revocation are checked before write",function()
    for _,mode in ipairs({"time","revoke"}) do
        local a,f=fixture();setup(a);a:transmit("p",tok(),"abc",100)
        local out=a:service("p",function() if mode=="time" then f.now=100;return true end;return false end,ready())
        assert(out.calls==0 and out.event.kind=="error")
    end
end)
test("partial TX and post-syscall deadline retain uncertainty",function()
    local a,f=fixture();setup(a);a:transmit("p",tok(),"abc",100)
    f.write=function() f.now=100;return 1 end
    local out=a:service("p",permit,ready())
    assert(out.event.code=="expired" and out.event.may_have_sent and out.bytes==1)
end)
test("EINTR and EAGAIN never loop inside a pass",function()
    for _,errno in ipairs({"EINTR","EAGAIN"}) do
        local a,f=fixture();setup(a);a:transmit("p",tok(),"abc",100)
        f.write=function() return nil,errno end
        local out=a:service("p",permit,ready());assert(out.calls==1 and not out.event)
        f.now=100;assert(a:service("p",permit,ready()).calls==0)
    end
end)
test("write exception is conservatively uncertain",function()
    local a,f=fixture();setup(a);a:transmit("p",tok(),"abc",100)
    f.write=function() error("injected") end
    local out=a:service("p",permit,ready())
    assert(out.event.may_have_sent and out.event.code=="callback_error")
end)
test("RTU completion is explicit, false is not completion",function()
    local a,f=fixture();setup(a,"rtu");a:transmit("p",tok(),"abc",100)
    a:service("p",permit,ready());f.tx_empty=function() return false end
    assert(not a:service("p",permit).event)
    f.tx_empty=function() return true end;f.now=1
    assert(a:service("p",permit).event.kind=="tx_complete")
end)
test("read capacity, zero capacity and TCP EOF",function()
    local a,f=fixture();setup(a);send(a)
    local rd=ready();rd.capacity=0
    assert(a:service("p",permit,rd).calls==0)
    rd.capacity=12
    f.read=function(_,n) assert(n==12);return string.rep("x",n) end
    local out=a:service("p",permit,rd);assert(out.bytes==12 and #out.event.data==12)
    f.read=function() return "" end
    assert(a:service("p",permit,rd).event.code=="eof")
end)
test("old operation and retry readiness cannot transmit",function()
    local a=fixture();setup(a);send(a);a:finish("p",tok())
    a:begin("p",tok(2),100);a:transmit("p",tok(2),"a",100)
    assert(a:service("p",permit,ready()).calls==0)
    assert(a:service("p",permit,ready(tok(2))).event.count==1)
    fails(function() a:begin("p",tok(),100) end)
end)
test("cancel emits one error and close; no double close",function()
    local a,f=fixture();setup(a);a:transmit("p",tok(),"abc",100)
    assert(a:cancel("p",tok()));assert(a:cancel("p",tok()))
    assert(a:service("p",permit,ready()).event.code=="cancelled")
    assert(a:service("p",permit).event.kind=="closed")
    assert(not a:service("p",permit).event and f.closed==1)
    assert(not a:cancel("p",tok()))
end)
test("all preparation failures release descriptor ownership",function()
    for _,phase in ipairs({"open","configure","connect","connect_status"}) do
        local a,f=fixture()
        if phase=="connect_status" then f.connect=function() return nil,"EINPROGRESS" end end
        f[phase]=function() return nil,"EIO" end
        local c=phase=="configure" and {kind="rtu",address="/fake/tty",baud=115200} or cfg
        a:prepare("p",c,tok(),100)
        local out=a:service("p",permit,ready())
        if not out.event then f.now=1;out=a:service("p",permit,ready()) end
        assert(out.event.code=="EIO")
        a:service("p",permit)
        assert(f.closed==(phase=="open" and 0 or 1))
    end
end)
test("close error never retries a reused Linux descriptor",function()
    local a,f=fixture();setup(a)
    local n=0;f.close=function() n=n+1;return nil,"EINTR" end
    a:close("p");assert(a:service("p",permit).event.code=="EINTR")
    a:service("p",permit);assert(n==1)
    a:prepare("p",cfg,tok(1,1,2),100)
    assert(a:service("p",permit).event.kind=="prepared")
    assert(not a:cancel("p",tok()))
end)
test("wait excludes idle POLLOUT and bounds timeout",function()
    local a,f=fixture();setup(a);a:wait(100);assert(#f.interests==0)
    a:transmit("p",tok(),"abc",100);f.now=95
    a:wait(100);assert(f.timeout==5 and #f.interests==1 and f.interests[1].writable)
    a:cancel("p",tok());a:wait(100);assert(f.timeout==0)
end)
test("wakeup coalesces and stale poll tokens are discarded",function()
    local a,f=fixture();setup(a)
    a:notify();a:notify();assert(f.wakes==1)
    f.poll=function() return {wake=true,p=ready(tok(9))} end
    local out=a:wait(10);assert(next(out)==nil and f.drains==1)
    a:notify();assert(f.wakes==2)
    f.poll=function() return nil,"EINTR" end
    local x,err=a:wait(10);assert(not x and err=="EINTR")
end)
test("seven endpoints keep independent finite budgets",function()
    local a=fixture()
    for i=1,7 do
        a:prepare(tostring(i),cfg,tok(),100)
        local out=a:service(tostring(i),permit)
        assert(out.calls<=4 and out.bytes<=512 and out.event.kind=="prepared")
    end
    fails(function() a:prepare("8",cfg,tok(),100) end)
end)
test("setup retry waits without zero-time spinning",function()
    local a,f=fixture();f.open=function() return nil,"EAGAIN" end
    a:prepare("p",cfg,tok(),100)
    assert(a:service("p",permit).calls==1)
    a:wait(10);assert(f.timeout==1)
    assert(a:service("p",permit).calls==0)
    f.now=1;assert(a:service("p",permit).calls==1)
end)
test("partial write rechecks permission before continuation",function()
    local a,f=fixture();setup(a);a:transmit("p",tok(),"abc",100)
    f.write=function() return 1 end
    assert(a:service("p",permit,ready()).event.count==1)
    local out=a:service("p",function() return false end,ready())
    assert(out.calls==0 and out.event.code=="revoked" and out.event.may_have_sent)
end)
test("RX byte ceiling and post-read deadline",function()
    local a,f=fixture();setup(a);send(a)
    f.read=function(_,n) assert(n==512);return string.rep("x",n) end
    assert(a:service("p",permit,ready()).bytes==512)
    f.read=function() f.now=100;return "late" end
    local out=a:service("p",permit,ready())
    assert(out.event.kind=="error" and out.event.data==nil)
end)
test("new attempt rejects old readiness and zero write fails",function()
    local a,f=fixture();setup(a);send(a);a:finish("p",tok())
    a:begin("p",tok(1,2),100);a:transmit("p",tok(1,2),"a",100)
    assert(a:service("p",permit,ready()).calls==0)
    f.write=function() return 0 end
    assert(a:service("p",permit,ready(tok(1,2))).event.code=="zero_write")
end)
print("[io-adapter] "..count.." tests passed")
