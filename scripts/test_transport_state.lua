-- Core TC-111..115/120/121/131. Controlled clock and fake byte I/O only.
package.path="./pkg/usr/lib/?.lua;"..package.path
local m=require("modbus.transport_state")
local count=0
local function test(name,fn) fn();count=count+1;print("[lua-state] OK "..name) end
local function req(fields)
    local q={operation_id="op",device_id="board",safe_read=true}
    for k,v in pairs(fields or {}) do q[k]=v end
    return q
end
local function ready(kind,opts,q)
    local clock={now=0}
    local t=m.new(kind or "tcp",opts,function() return clock.now end)
    if t.kind=="rtu" then t:confirm_sync("synthetic reset");clock.now=t.gap;t:tick(clock.now) end
    assert(t:admit(q or req()));assert(t:begin());t:setup_done(t.generation)
    return t,clock
end
local function at(t,c,now) c.now=now;t:tick(now) end
local function send(t)
    -- Fake backend: wire is the outbound buffer; completions may be partial.
    t:tx(#t.wire-t.sent,t.generation);t:tx_complete(t.generation)
    assert(t.state=="receive")
end
local function response(t,pdu)
    pdu=pdu or string.char(3,2,18,52)
    return t.kind=="tcp" and m.tcp_frame(t.tid,t.op.unit,pdu)
        or m.rtu_frame(string.char(t.op.unit)..pdu)
end
local function result(t,want)
    local list=t:drain_results()
    assert(#list==1 and list[1].outcome==want,(list[1] and list[1].outcome or "none").." != "..want)
    return list[1]
end
local bounded={policy="bounded",late_bound=800,timing_profile="synthetic",retries=1}
test("known CRC and rounded silence",function()
    local wire=string.char(1,3,0,0,0,10,197,205)
    assert(m.rtu_frame(wire:sub(1,-3))==wire and m.crc(wire)==0)
    assert(m.silence_ms(9600)==4 and m.silence_ms(19200)==2 and m.silence_ms(115200)==2)
end)
test("every split TCP and RTU",function()
    for _,kind in ipairs({"tcp","rtu"}) do
        for split=1,(kind=="tcp" and 10 or 6) do
            local t,c=ready(kind);send(t);local frame=response(t)
            t:receive(frame:sub(1,split),t.generation);assert(#t.results==0)
            at(t,c,t.da-1);t:receive(frame:sub(split+1),t.generation)
            assert(result(t,"ok").data==string.char(18,52))
        end
    end
end)
test("injected clock expires buffered response at exact deadline",function()
    for _,kind in ipairs({"tcp","rtu"}) do
        local t,c=ready(kind);send(t);local frame,gen=response(t),t.generation
        c.now=t.da -- No explicit tick: event must consult the clock first.
        t:receive(frame,gen);result(t,"timeout");assert(not t.valid)
    end
end)
test("partial bytes do not reset deadline",function()
    local t,c=ready();send(t);local f=response(t)
    at(t,c,499);t:receive(f:sub(1,8),t.generation)
    at(t,c,500);t:receive(f:sub(9),t.generation);result(t,"timeout")
end)
test("queue expiry includes pre-admission wait",function()
    local t=m.new("tcp");t:tick(200)
    assert(t:admit(req(),nil,0));t:tick(10000)
    assert(not t:begin());assert(result(t,"expired").attempts==0)
    local x=m.new("tcp");x:admit(req(),50);x:tick(50)
    result(x,"expired");assert(x.wire=="")
end)
test("setup failures exhaust retry budget",function()
    local t=m.new("tcp",{retries=3,setup_timeout=100})
    t:admit(req());t:begin()
    for i=1,4 do t:tick(t.setup_deadline);if i<4 then t:tick(t.retry_at) end end
    local r=result(t,"timeout");assert(r.attempts==4 and r.sent_attempts==0)
end)
test("default and unsafe reads do not retry",function()
    local t,c=ready();send(t);at(t,c,t.da);assert(result(t,"timeout").attempts==1)
    t,c=ready("tcp",{retries=3},req({safe_read=false}))
    send(t);t:io_error(t.generation);assert(result(t,"io_error").attempts==1)
end)
test("all Modbus exceptions terminal including busy",function()
    for _,kind in ipairs({"tcp","rtu"}) do
        local t=ready(kind,{retries=3});send(t)
        t:receive(response(t,string.char(131,6)),t.generation)
        local r=result(t,"modbus_exception");assert(r.exception_code==6 and r.attempts==1)
    end
end)
test("partial TX EAGAIN and completion share deadline",function()
    local t,c=ready();t:tx(0,t.generation);local da=t.da
    at(t,c,100);t:tx(3,t.generation)
    at(t,c,499);send(t);assert(t.da==da)
    at(t,c,500);result(t,"timeout")
end)
test("partial RTU or absent TX completion require manual recovery",function()
    for _,partial in ipairs({true,false}) do
        local t,c=ready("rtu",bounded)
        t:tx(partial and 1 or #t.wire)
        at(t,c,t.da);result(t,"timeout");assert(t.state=="desynchronized")
    end
end)
test("manual late response cannot satisfy new address",function()
    local t,c=ready("rtu");send(t);local old=response(t)
    at(t,c,t.da);result(t,"timeout")
    assert(t:admit(req({address=100})));assert(not t:begin())
    t:receive(old);assert(t.state=="desynchronized" and #t.results==0)
    t:cancel();result(t,"cancelled")
end)
test("new RTU instance requires explicit synchronization",function()
    local t=m.new("rtu");assert(t:admit(req()));assert(not t:begin())
    t:tick(10000);result(t,"expired");assert(t.state=="desynchronized")
    t:confirm_sync("operator evidence");assert(t.state=="idle")
    assert(m.new("rtu").state=="desynchronized")
end)
test("bounded quarantine retry respects last-byte silence",function()
    local t,c=ready("rtu",bounded);send(t)
    local f=response(t);local bound=t.last_write+800
    at(t,c,t.da);assert(t.state=="quarantine")
    at(t,c,bound);t:receive(f);assert(not t.valid and #t.results==0)
    at(t,c,bound+1);assert(t.state=="quarantine")
    at(t,c,bound+t.gap);assert(t.state=="setup")
    t:setup_done();send(t);t:receive(response(t));assert(result(t,"ok").attempts==2)
end)
test("byte beyond bound desynchronizes",function()
    local t,c=ready("rtu",bounded);send(t);local f=response(t)
    local bound=t.last_write+800
    at(t,c,t.da);at(t,c,bound);t:receive(f)
    at(t,c,bound+1);t:receive("x")
    result(t,"desynchronized");assert(t.state=="desynchronized")
end)
test("operation expiry does not release quarantine",function()
    local opts={policy="bounded",late_bound=800,timing_profile="synthetic",retries=3,operation_timeout=600}
    local t,c=ready("rtu",opts);send(t)
    at(t,c,t.da);at(t,c,t.dop);result(t,"timeout")
    assert(t.state=="quarantine" and not t:admit(req()))
    at(t,c,803);assert(t.state=="idle")
end)
test("CRC error invalidates but preserves last success",function()
    local t,c=ready("rtu");send(t);t:receive(response(t));result(t,"ok")
    local last=t.last_success
    at(t,c,t.ready_at);t:admit(req());t:begin();t:setup_done();send(t)
    local f=response(t);t:receive(f:sub(1,-2)..string.char((f:byte(-1)+1)%256))
    result(t,"protocol_error");assert(not t.valid and t.last_success==last)
end)
test("TCP old generations and deadline-triggered callbacks ignored",function()
    local t,c=ready("tcp",{retries=1});send(t)
    local old,frame=t.generation,response(t);c.now=t.da
    t:receive(frame,old);assert(t.state=="retry" and #t.results==0)
    at(t,c,t.retry_at)
    t:setup_done(old);assert(t.state=="setup")
    t:setup_done(t.generation);send(t)
    t:receive(frame,old);t:io_error(old);t:tx_complete(old);assert(#t.results==0)
    t:receive(response(t),t.generation);assert(result(t,"ok").attempts==2)
end)
test("MBAP protocol id unit and length faults terminal",function()
    for _,change in ipairs({{1,9},{3,1},{5,1},{5,255},{7,2}}) do
        local t=ready("tcp",{retries=3});send(t)
        local f=response(t);local pos=change[1]
        if pos<7 then pos=pos+1 end
        f=f:sub(1,pos-1)..string.char(change[2])..f:sub(pos+1)
        t:receive(f,t.generation);result(t,"protocol_error");assert(not t.connected)
    end
end)
test("PDU function count and zero exception rejected",function()
    for _,p in ipairs({string.char(4,2,0,0),string.char(3,1,0),string.char(131,0)}) do
        local t=ready();send(t);t:receive(response(t,p),t.generation);result(t,"protocol_error")
    end
end)
test("coalesced extra frame closes without duplicate result",function()
    for _,kind in ipairs({"tcp","rtu"}) do
        local t=ready(kind);send(t);local f=response(t)
        t:receive(f..f,t.generation);result(t,"ok");assert(#t:drain_results()==0)
        assert(kind=="tcp" and not t.connected or kind=="rtu" and t.state=="desynchronized")
    end
end)
test("TID exhaustion creates new generation",function()
    local t=ready();send(t);t:receive(response(t),t.generation);result(t,"ok")
    local old=t.generation;t.next_tid=65535 -- Test-only boundary injection.
    for _,tid in ipairs({65535,0}) do
        t:admit(req());t:begin();t:setup_done(t.generation);assert(t.tid==tid)
        send(t);t:receive(response(t),t.generation);result(t,"ok")
    end
    assert(t.generation>old)
end)
test("writes never retry and retain uncertainty",function()
    for _,kind in ipairs({"tcp","rtu"}) do
        for _,sent in ipairs({false,true}) do
            local t=ready(kind,{retries=3},req({["function"]=6,count=1,safe_read=false}))
            if sent then t:tx(1,t.generation) end
            t:cancel();local r=result(t,"cancelled")
            assert(r.write_outcome==(sent and "unknown" or "not_sent") and r.attempts==1)
        end
        local t=ready(kind,nil,req({["function"]=6,count=1,safe_read=false}))
        send(t);t:receive(response(t,string.char(6,0,0,0,1)),t.generation)
        assert(result(t,"ok").write_outcome=="confirmed")
    end
end)
test("EOF safe read retries in new connection",function()
    local t=ready("tcp",{retries=1});send(t);t:receive("",t.generation)
    assert(t.state=="retry" and not t.connected)
end)
test("bounded RX and largest read responses",function()
    local t=ready();send(t)
    assert(not pcall(function() t:receive(string.rep("x",513),t.generation) end))
    t:receive(string.rep("x",512),t.generation);result(t,"protocol_error")
    t=ready("rtu");send(t);t:receive(string.rep("x",257));result(t,"protocol_error")
    for _,kind in ipairs({"rtu","tcp"}) do
        for _,x in ipairs({{1,2000,250},{2,9,2},{3,125,250},{4,125,250}}) do
            t=ready(kind,nil,req({["function"]=x[1],count=x[2]}));send(t)
            t:receive(response(t,string.char(x[1],x[3])..string.rep("\0",x[3])),t.generation)
            assert(#result(t,"ok").data==x[3])
        end
    end
end)
test("ports isolated and terminal result backpressure",function()
    local a,c=ready("rtu");local b=ready("rtu");send(a);send(b)
    at(a,c,a.da);b:receive(response(b));result(b,"ok")
    assert(not a:admit(req()));a:cancel();result(a,"timeout")
    assert(#a:drain_results()==0)
end)
test("device validity and observations bounded",function()
    local t=ready();send(t);t:receive(response(t),t.generation);result(t,"ok")
    t:admit(req({device_id="other"}));assert(not t.valid and t.last_success==nil)
    t:cancel();result(t,"cancelled");assert(t.samples.board.valid)
    local x=m.new("tcp")
    for i=1,32 do x:admit(req({device_id=tostring(i)}));x:cancel();result(x,"cancelled") end
    assert(not pcall(function() x:admit(req({device_id="33"})) end))
end)
test("retry invalidates immediately without changing last success",function()
    local t=ready("tcp",{retries=1});send(t);t:receive(response(t),t.generation);result(t,"ok")
    local last=t.last_success
    t:admit(req());t:begin();t:setup_done(t.generation);send(t);t:io_error(t.generation)
    assert(t.state=="retry" and not t.valid and t.last_success==last)
end)
test("defensive request copy and strict validation",function()
    local q=req();local t=ready("tcp",nil,q);q.count=125;assert(t.op.count==1)
    for _,opts in ipairs({{retries=true},{retries=4},{request_timeout=99},{operation_timeout=499},
                         {policy="bounded"},{policy="bounded",late_bound=1},{baud=12345},{extra=1}}) do
        assert(not pcall(m.new,"rtu",opts))
    end
    assert(not pcall(m.new,"tcp",false))
    for _,fields in ipairs({{unit=256},{count=126},{address=65535,count=2},
                           {["function"]=6},{safe_read=1},{extra=1}}) do
        local x=m.new("tcp");assert(not pcall(x.admit,x,req(fields)))
    end
    local x=m.new("tcp");x:tick(100)
    assert(not pcall(x.tick,x,99));assert(not pcall(x.tick,x,0/0))
    assert(not pcall(x.admit,x,req(),nil,false))
end)
test("deadline arithmetic saturates without wrapping",function()
    local t=m.new("tcp");t:tick(9007199254740990)
    assert(t:admit(req()));assert(t.dop==9007199254740991)
    t:tick(9007199254740991);result(t,"expired")
end)
test("deadline checked before setup and TX completion events",function()
    local clock={now=0}
    local t=m.new("tcp",nil,function() return clock.now end)
    t:admit(req());t:begin();local gen=t.generation
    clock.now=t.setup_deadline;t:setup_done(gen)
    assert(t.wire=="");result(t,"timeout")
    local x,c=ready()
    c.now=x.dop;x:tx(1,x.generation)
    assert(result(x,"expired").sent_attempts==0)
end)
print("[test_transport_state] OK: "..count.." cases")
