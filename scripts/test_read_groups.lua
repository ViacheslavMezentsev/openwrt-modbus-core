-- Core TC-69..71/119/125/126/133: no native I/O or router.
package.path="./pkg/usr/lib/?.lua;"..package.path
local st=require("modbus.transport_state")
local sched=require("modbus.transport_scheduler")
local loader=require("modbus.device_profiles")
local groups=require("modbus.read_groups")
local count=0
local function test(n,f) f();count=count+1;print("[lua-groups] OK "..n) end
local function fails(f) assert(not pcall(f),"expected rejection") end
local function range(fc,n,limit,gap,safe,merge,start)
    return string.format('{"function":%d,"start":%d,"count":%d,"max_count":%d,"max_gap":%d,"safe_read":%s,"mergeable":%s}',
        fc or 3,start or 0,n or 100,limit or 20,gap or 0,tostring(safe~=false),tostring(merge~=false))
end
local function snapshot(ranges,bindings)
    local store=assert(loader.new(function(id)
        return '{"id":"'..id..'","read_ranges":['..(ranges or range())..']}'
    end))
    return assert(store:activate(bindings or {d="test"},true,0)),store
end
local function new(ranges,opts,kind)
    opts=opts or {};opts.profiles=snapshot(ranges)
    local t=st.new(kind or "tcp",{transport_id="p",baud=9600})
    if kind=="rtu" then t:confirm_sync("synthetic reset") end
    return sched.new({t},opts),t
end
local function put(s,id,address,n,fc,opts,fields)
    local q={operation_id=id,device_id="d",address=address or 0,count=n or 1,["function"]=fc or 3}
    for k,v in pairs(fields or {}) do q[k]=v end
    return s:enqueue("p",q,opts)
end
local function ev(t,k,d) return {kind=k,data=d,generation=t.generation} end
local function send(s,t,now)
    s:step(now,{[t.transport_id]=ev(t,"setup")})
    s:step(now,{[t.transport_id]=ev(t,"tx",#t.wire)})
    s:step(now,{[t.transport_id]=ev(t,"tx_complete")})
end
local function data(fc,address,n)
    local b={}
    if fc<=2 then
        for base=0,n-1,8 do
            local v=0
            for j=0,math.min(7,n-base-1) do
                if (address+base+j)%3==0 then v=v+2^j end
            end
            b[#b+1]=string.char(v)
        end
    else
        for i=address,address+n-1 do b[#b+1]=string.char(math.floor(i/256),i%256) end
    end
    return table.concat(b)
end
local function response(s,t,now,exception)
    local q=t.op;local fc=q["function"];local pdu
    if exception then pdu=string.char(fc+128,2)
    elseif fc==6 then pdu=string.char(6,math.floor(q.address/256),q.address%256,math.floor(q.count/256),q.count%256)
    else local d=data(fc,q.address,q.count);pdu=string.char(fc,#d)..d end
    local frame=t.kind=="tcp" and st.tcp_frame(t.tid,q.unit,pdu) or st.rtu_frame(string.char(q.unit)..pdu)
    return s:step(now,{[t.transport_id]=ev(t,"rx",frame)})
end
local function exchange(s,t,now,exception) send(s,t,now);return response(s,t,now,exception) end
test("overlap duplicates fanout and exact payload",function()
    local s,t=new()
    put(s,"a",2,4);put(s,"b",4,4);put(s,"c",2,4);s:step(0)
    assert(t.op.address==2 and t.op.count==6 and s.pool:used()==12)
    local out=exchange(s,t,1).results
    assert(#out==3 and out[1].data==data(3,2,4) and out[2].data==data(3,4,4))
    assert(out[3].data==out[1].data and out[2].operation_id=="b" and s.pool:used()==0)
end)
test("gaps and adjacent map boundaries",function()
    for gap=0,2 do
        local s,t=new(range(3,20,20,gap))
        put(s,"a",0,2);put(s,"b",4,2);s:step(0)
        assert(t.op.count==(gap==2 and 6 or 2))
    end
    local s,t=new(range(3,2,2)..","..range(3,2,2,0,true,true,2))
    put(s,"a",0,2);put(s,"b",2,2);s:step(0)
    assert(t.op.count==2 and #s.queues.p==1)
    fails(function() put(s,"cross",1,2) end)
end)
test("holes unknown devices and client safety override",function()
    local s,t=new(range(3,10,10,0,false,false))
    fails(function() put(s,"hole",9,2) end)
    fails(function() put(s,"unknown",0,1,3,nil,{device_id="other",unit=2}) end)
    put(s,"a",0,1,3,nil,{safe_read=true});put(s,"b",1);s:step(0)
    assert(not t.op.safe_read and t.op.count==1)
    fails(function() sched.new({st.new("tcp")},{profiles={}}) end)
end)
test("FIFO function, write and readback barriers",function()
    for _,barrier in ipairs({"function","write","readback"}) do
        local s,t=new(range()..","..range(4))
        put(s,"a")
        put(s,"barrier",1,1,barrier=="function" and 4 or barrier=="write" and 6 or 3,
            {readback=barrier=="readback"})
        put(s,"b",2);s:step(0);assert(t.op.count==1)
        exchange(s,t,1);assert(t.op.operation_id=="barrier")
        exchange(s,t,2);assert(t.op.operation_id=="b")
    end
end)
test("writes unchanged, including zero and duplicates",function()
    local s,t=new()
    put(s,"a",7,0,6);put(s,"b",7,0,6);s:step(0)
    assert(t.op.count==0 and s.pool:used()==0)
    assert(exchange(s,t,1).results[1].write_outcome=="confirmed")
    assert(t.op.operation_id=="b" and t.op.count==0)
    exchange(s,t,2);assert(s.pool:used()==0)
end)
test("minimum group deadline and original start",function()
    local s,t=new();put(s,"a",0,1,3,{expiry=500})
    s.now=10;put(s,"b",1,1,3,{expiry=100});s:step(10)
    assert(t.dop==100)
    local out=exchange(s,t,20).results
    assert(out[1].start==0 and out[2].start==10 and out[1]["end"]==20)
end)
test("consumer limits and active duplicate detection",function()
    local s,t=new(nil,{queue_limit=3})
    for i=1,3 do put(s,tostring(i),i) end
    s:step(0)
    assert(put(s,"four",4)=="accepted" and put(s,"five",5)=="busy")
    fails(function() put(s,"2",2) end)
    local a,b=new()
    for i=1,17 do put(a,tostring(i)) end
    a:step(0);assert(#a.groups.p.group.entries==16 and #a.queues.p==1)
    assert(#exchange(a,b,1).results==16)
end)
test("unsafe split rejected and nonmergeable reads stay separate",function()
    local s,t=new(range(3,20,2,0,false,false))
    fails(function() put(s,"bad",0,3) end);assert(#s.queues.p==0)
    local a,b=new(range(3,20,20,0,true,false))
    put(a,"a");put(a,"b",1);a:step(0);assert(b.op.count==1)
end)
test("split assembles only full result and aggregates attempts",function()
    local s,t=new(range(3,20,2))
    put(s,"a",0,5);s:step(0);local a=s.groups.p
    assert(s.pool:used()==10)
    assert(#exchange(s,t,1).results==0 and not t.valid and not t.samples.d.valid)
    assert(t.last_success==nil and t.samples.d.last_success==nil and a.index==1)
    assert(#exchange(s,t,2).results==0 and t.op.count==1)
    local out=exchange(s,t,3).results[1]
    assert(out.data==data(3,0,5) and out.attempts==3 and out.sent_attempts==3)
    assert(t.samples.d.last_success==3 and t.valid and s.pool:used()==0 and a.buffer=="")
end)
test("failed later fragment preserves previous full success",function()
    local s,t=new(range(3,20,2))
    put(s,"first");s:step(0);exchange(s,t,1)
    put(s,"split",0,5);s:step(2);exchange(s,t,3)
    assert(t.samples.d.last_success==1 and not t.samples.d.valid)
    local out=exchange(s,t,4,true).results[1]
    assert(out.outcome=="modbus_exception" and out.data=="" and out.attempts==2)
    assert(t.last_success==1 and t.samples.d.last_success==1 and not t.op and s.pool:used()==0)
end)
test("bit fanout zero padding and non-byte split",function()
    local s,t=new(range(1,100,20))
    put(s,"a",1,9,1);put(s,"b",3,7,1);s:step(0)
    local out=exchange(s,t,1).results
    assert(out[1].data==data(1,1,9) and out[2].data==data(1,3,7))
    local a,b=new(range(2,100,5))
    put(a,"split",0,19,2);a:step(0)
    for i=1,3 do assert(#exchange(a,b,i).results==0) end
    assert(exchange(a,b,4).results[1].data==data(2,0,19))
end)
test("logical sizes above wire limits and exact limits",function()
    for _,fc in ipairs({1,2,3,4}) do
        local n=fc<=2 and 8192 or 512
        local limit=fc<=2 and 2000 or 125
        local s,t=new(range(fc,n+1,limit))
        put(s,"max",0,n,fc);fails(function() put(s,"over",0,n+1,fc) end)
        s:step(0);assert(s.pool:used()==1024)
        local out
        for i=1,math.ceil(n/limit) do out=exchange(s,t,i).results end
        assert(out[1].data==data(fc,0,n) and #out[1].data==1024 and s.pool:used()==0)
    end
end)
test("fragment count 16 accepted 17 rejected before queue",function()
    local s,t=new(range(3,100,2))
    put(s,"a",0,32);fails(function() put(s,"b",0,33) end)
    assert(#s.queues.p==1)
    s:step(0);assert(s.groups.p.index==0 and not s.groups.p.wires)
    for i=1,15 do assert(#exchange(s,t,i).results==0) end
    assert(exchange(s,t,16).results[1].attempts==16)
end)
test("group cannot skip incompatible FIFO head",function()
    local s,t=new(range(3,20,3))
    put(s,"a",0,2);put(s,"b",2,2);put(s,"c",0,1);s:step(0)
    assert(t.op.count==2 and #s.queues.p==2 and s.queues.p[1].request.operation_id=="b")
end)
test("RTU split owns barrier and expires during silence",function()
    local s,t=new(range(3,20,1),nil,"rtu")
    put(s,"a",0,2,3,{expiry=6});s:step(4)
    assert(#exchange(s,t,5).results==0 and s.pending.p and not t.op)
    assert(s.pool:used()==4 and s:next_wait()==1)
    local out=s:step(6).results[1]
    assert(out.outcome=="timeout" and out.data=="" and not s.pending.p)
    assert(t.last_success==nil and t.samples.d.last_success==nil and s.pool:used()==0)
end)
test("active timeout discards all partial bytes",function()
    local s,t=new(range(3,20,2))
    put(s,"a",0,5,3,{expiry=3});s:step(0);exchange(s,t,1)
    local out=s:step(3).results[1]
    assert(out.outcome=="timeout" and out.data=="" and out.start==0 and s.pool:used()==0)
    assert(not t.valid and t.samples.d.last_success==nil)
end)
test("cancel during active fragment and RTU gap releases reserve",function()
    for _,kind in ipairs({"tcp","rtu"}) do
        local s,t=new(range(3,20,1),nil,kind)
        put(s,"a",0,3);s:step(4);exchange(s,t,5)
        assert(s:cancel("p") and s:next_wait()==0)
        local out=s:step(5).results[1]
        assert(out.outcome=="cancelled" and out.data=="" and s.pool:used()==0)
        assert(not s:cancel("p") and not s.pending.p and not t.valid)
    end
end)
test("memory wait retains FIFO deadline and services IPC",function()
    local pool=groups.pool(4);local owner={}
    assert(pool:acquire(owner,4))
    local s,t=new(nil,{assembly_pool=pool})
    put(s,"a",0,2,3,{expiry=20});s:post_ipc(10)
    assert(s:step(0).ipc_serviced==8 and not t.op and #s.queues.p==1)
    s:step(1);assert(s:next_wait()>0)
    pool:release(owner);s:step(2)
    assert(t.dop==20 and pool:used()==4)
    assert(exchange(s,t,3).results[1].start==0 and pool:used()==0)
end)
test("memory-blocked RTU excluded, other endpoint progresses",function()
    local snap=snapshot(range(),{a="test",b="test"})
    local a=st.new("rtu",{transport_id="a"});a:confirm_sync("fake")
    local b=st.new("tcp",{transport_id="b"})
    local pool=groups.pool(2)
    local s=sched.new({a,b},{profiles=snap,assembly_pool=pool})
    s:enqueue("a",{operation_id="a",device_id="a",count=2},{expiry=10})
    s:enqueue("b",{operation_id="b",device_id="b"})
    local out=s:step(2)
    assert(#out.round_started==0 and s.round_number==0 and not s.pending.a and b.op)
    assert(exchange(s,b,3).results[1].outcome=="ok")
    assert(s:step(10).results[1].outcome=="expired" and pool:used()==0)
end)
test("pool exact budget and invalid release",function()
    local pool=groups.pool();local owners={}
    for i=1,8 do owners[i]={};assert(pool:acquire(owners[i],1024)) end
    assert(pool:used()==8192 and not pool:acquire({},1))
    fails(function() pool:acquire(owners[1],0) end)
    for i=1,8 do pool:release(owners[i]) end
    assert(pool:used()==0)
    fails(function() pool:release(owners[1]) end)
    fails(function() groups.pool(8193) end)
end)
test("snapshot replacement cannot alter active scheduler map",function()
    local snap,store=snapshot(range())
    local t=st.new("tcp",{transport_id="p"})
    local s=sched.new({t},{profiles=snap})
    assert(store:activate({},true,0))
    put(s,"a",0,2);put(s,"b",2,2);s:step(0)
    assert(t.op.count==4 and #exchange(s,t,1).results==2)
end)
test("exception fails all consumers without speculative splitting",function()
    local s,t=new()
    put(s,"a",0,2);put(s,"b",2,2);s:step(0)
    local out=exchange(s,t,1,true).results
    assert(#out==2 and out[1].data=="" and out[2].data=="" and out[2].exception_code==2)
    assert(not t.op and not s.groups.p and s.pool:used()==0)
end)
test("fragment retry keeps reservation and aggregates attempts",function()
    local snap=snapshot(range(3,20,1))
    local t=st.new("tcp",{transport_id="p",retries=1,request_timeout=100})
    local s=sched.new({t},{profiles=snap})
    put(s,"a",0,2);s:step(0);exchange(s,t,1);send(s,t,2)
    assert(#s:step(102).results==0 and s.pool:used()==4)
    s:step(1102)
    local out=exchange(s,t,1103).results[1]
    assert(out.attempts==3 and out.sent_attempts==3 and out.data==data(3,0,2))
    assert(s.pool:used()==0)
end)
test("RTU fragment barrier preserves other ports and pass quotas",function()
    local snap=snapshot(range(3,20,1),{a="test",b="test",c="test"})
    local p={}
    for i,name in ipairs({"a","b","c"}) do
        p[i]=st.new(i==3 and "tcp" or "rtu",{transport_id=name})
        if i<3 then p[i]:confirm_sync("fake") end
    end
    local s=sched.new(p,{profiles=snap})
    for _,name in ipairs({"a","b","c"}) do
        s:enqueue(name,{operation_id="first",device_id=name,count=name=="a" and 2 or 1})
        s:enqueue(name,{operation_id="second",device_id=name,address=5})
    end
    s:step(2);exchange(s,p[2],3);exchange(s,p[3],3)
    assert(p[3].op and not p[2].op and s.round_number==1)
    exchange(s,p[1],4);assert(s.pending.a and s.round_number==1)
    s:step(6)
    local out=exchange(s,p[1],7)
    assert(#out.results==1 and s.round_number==2 and p[2].op)
    for _,v in pairs(out.transitions) do assert(v<=8) end
end)
test("malformed wire result releases entire group reservation",function()
    local s,t=new();put(s,"a");put(s,"b",1);s:step(0);send(s,t,1)
    local out=s:step(2,{p=ev(t,"rx",string.rep("x",512))}).results
    assert(#out==2 and out[1].outcome~="ok" and out[2].data=="" and s.pool:used()==0)
end)
test("blocked shared pool retries without deadline extension",function()
    local pool=groups.pool(2)
    local a,ta=new(nil,{assembly_pool=pool})
    local b,tb=new(nil,{assembly_pool=pool})
    put(a,"a");put(b,"b",0,1,3,{expiry=20})
    a:step(0);b:step(0);assert(not tb.op and b:next_wait()>0)
    exchange(a,ta,1);b:step(2)
    assert(tb.op and tb.dop==20 and pool:used()==2)
    exchange(b,tb,3);assert(pool:used()==0)
end)
print("[lua-groups] "..count.." tests passed")
