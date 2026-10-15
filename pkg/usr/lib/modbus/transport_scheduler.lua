-- Core 6.8.2/13/14/15: isolated FIFO/round composition, no real I/O or IPC.
local state = require("modbus.transport_state")
local M,S={},{}
S.__index=S
local MAX=9007199254740991
local function int(n,lo,hi)
    assert(type(n)=="number" and n==math.floor(n) and n>=lo and n<=hi,"integer")
end
local function plain(t) assert(type(t)=="table" and getmetatable(t)==nil,"plain table") end
local function add(a,b) return a>MAX-b and MAX or a+b end
local function empty(t) return next(t)==nil end
function M.new(transports,options)
    plain(transports)
    if options==nil then options={} end;plain(options)
    local cfg={queue_limit=32,quantum=10,ipc_limit=128}
    for k,v in pairs(options) do assert(cfg[k]~=nil,"option");cfg[k]=v end
    int(cfg.queue_limit,1,128);int(cfg.quantum,1,100);int(cfg.ipc_limit,1,128)
    local n=0
    for k in pairs(transports) do int(k,1,7);n=n+1 end
    assert(n>0 and n==#transports,"dense endpoints")
    local self=setmetatable(cfg,S)
    self.ports,self.names,self.queues,self.devices={},{},{},{}
    local rtu,tcp=0,0
    for i=1,n do
        local t=transports[i]
        assert(type(t)=="table" and type(t.transport_id)=="string" and #t.transport_id>0,"endpoint")
        assert(not self.ports[t.transport_id],"duplicate endpoint")
        assert(t.kind=="rtu" or t.kind=="tcp","kind")
        assert(not t.op and #t.results==0 and t.now==0 and t.clock==nil,"fresh endpoint, scheduler-owned clock")
        if t.kind=="rtu" then rtu=rtu+1 else tcp=tcp+1 end
        assert(rtu<=3 and tcp<=4,"endpoint limits")
        self.ports[t.transport_id]=t;self.names[i]=t.transport_id;self.queues[t.transport_id]={}
    end
    self.now,self.cursor,self.ipc_pending,self.round_number=0,1,0,0
    self.members,self.pending={},{}
    return self
end
function S:enqueue(name,request,options)
    local t=assert(self.ports[name],"endpoint")
    local q=state.validate_request(request,t.kind)
    if options==nil then options={} end;plain(options)
    for k in pairs(options) do assert(k=="expiry" or k=="periodic" or k=="readback","enqueue option") end
    local periodic,readback=options.periodic,options.readback
    if readback==nil then readback=false end
    assert(type(readback)=="boolean" and not (readback and q["function"]==6),"readback")
    if options.expiry~=nil then int(options.expiry,0,MAX) end
    if periodic~=nil then
        assert(type(periodic)=="string" and #periodic>0 and #periodic<=32,"periodic key")
        assert(not readback and q["function"]<=4,"periodic reads only")
    end
    local binding=self.devices[q.device_id]
    if binding then assert(binding.port==name and binding.unit==q.unit,"identity rebind")
    else
        local n=0
        for _,v in pairs(self.devices) do
            n=n+1;assert(v.port~=name or v.unit~=q.unit,"identity alias")
        end
        assert(n<32,"device limit")
    end
    local queue=self.queues[name]
    if periodic then
        for _,entry in ipairs(queue) do
            if entry.periodic==periodic then
                for _,k in ipairs({"device_id","unit","function","address","count","safe_read"}) do
                    assert(entry.request[k]==q[k],"periodic plan changed")
                end
                return "coalesced"
            end
        end
    end
    assert(not t.op or t.op.operation_id~=q.operation_id,"duplicate active")
    for _,entry in ipairs(queue) do assert(entry.request.operation_id~=q.operation_id,"duplicate pending") end
    if #queue>=self.queue_limit then return "busy" end
    queue[#queue+1]={request=q,admitted=self.now,
        expiry=math.min(add(self.now,t.operation_timeout),options.expiry or MAX),
        periodic=periodic,readback=readback}
    self.devices[q.device_id]={port=name,unit=q.unit}
    return "accepted"
end
function S:post_ipc(n)
    if n==nil then n=1 end;int(n,1,self.ipc_limit)
    if self.ipc_pending+n>self.ipc_limit then return false end
    self.ipc_pending=self.ipc_pending+n;return true
end
function S:_expire(name,results)
    local kept,t={},self.ports[name]
    for _,e in ipairs(self.queues[name]) do
        if self.now>=e.expiry then
            local q=e.request
            results[#results+1]={operation_id=q.operation_id,device_id=q.device_id,
                transport_id=name,outcome="expired",attempts=0,sent_attempts=0,
                start=e.admitted,["end"]=self.now,
                write_outcome=q["function"]==6 and "not_sent" or nil,data=""}
            if t.samples[q.device_id] then
                t.samples[q.device_id].valid=false
                if t.current_device==q.device_id then t.valid=false end
            end
        else kept[#kept+1]=e end
    end
    self.queues[name]=kept
end
local function validate_event(event)
    plain(event)
    for k in pairs(event) do assert(k=="kind" or k=="data" or k=="generation","event field") end
    local k=event.kind
    assert(k=="setup" or k=="tx" or k=="tx_complete" or k=="rx" or k=="error","event kind")
    if k=="rx" then assert(type(event.data)=="string" and #event.data<=512,"RX event")
    elseif k=="tx" then int(event.data,0,512)
    else assert(event.data==nil,"unexpected payload") end
    if event.generation~=nil then int(event.generation,0,MAX) end
end
local function deliver(t,e)
    if e.kind=="setup" then t:setup_done(e.generation)
    elseif e.kind=="tx" then t:tx(e.data,e.generation)
    elseif e.kind=="tx_complete" then t:tx_complete(e.generation)
    elseif e.kind=="rx" then t:receive(e.data,e.generation)
    else t:io_error(e.generation) end
end
function S:step(now,events)
    int(now,self.now,MAX)
    if events==nil then events={} end;plain(events)
    -- Validate the complete batch before mutating time or queues.
    for name,e in pairs(events) do assert(self.ports[name],"event endpoint");validate_event(e) end
    self.now=now
    local out={results={},consumed={},order={},transitions={},io_bytes={},round_started={}}
    local before={}
    for i=1,#self.names do
        local name=self.names[(self.cursor+i-2)%#self.names+1]
        out.order[i]=name;before[name]=self.ports[name].transitions;out.io_bytes[name]=0
    end
    self.cursor=self.cursor%#self.names+1
    for _,name in ipairs(out.order) do
        local t=self.ports[name]
        t:tick(now)
        self:_expire(name,out.results)
        if events[name] and t.transitions-before[name]<=3 then
            local e=events[name]
            deliver(t,e) -- reserve five transitions, at most one 512-byte event
            out.consumed[#out.consumed+1]=name
            out.io_bytes[name]=e.kind=="rx" and #e.data or e.kind=="tx" and e.data or 0
        end
        local completed=t:drain_results()
        for _,value in ipairs(completed) do out.results[#out.results+1]=value end
        if #completed>0 then self.pending[name]=nil end
    end
    local eligible={}
    for _,name in ipairs(out.order) do
        local t=self.ports[name]
        if #self.queues[name]>0 and t.state=="idle" and not t.op and now>=t.ready_at
            and t.transitions-before[name]<=4 then eligible[#eligible+1]=name end
    end
    if empty(self.pending) then
        self.members={}
        for _,name in ipairs(eligible) do
            if self.ports[name].kind=="rtu" then
                self.members[name]=true;self.pending[name]=true
                out.round_started[#out.round_started+1]=name
            end
        end
        if #out.round_started>0 then self.round_number=self.round_number+1 end
    end
    for _,name in ipairs(eligible) do
        local t=self.ports[name]
        if t.kind=="tcp" or self.pending[name] then
            local e=table.remove(self.queues[name],1)
            assert(t:admit(e.request,e.expiry,e.admitted),"eligible admission")
            assert(t:begin() or #t.results>0,"eligible begin")
        end
    end
    out.ipc_serviced=math.min(8,self.ipc_pending) -- model work units, NOT wire IPC
    self.ipc_pending=self.ipc_pending-out.ipc_serviced
    for _,name in ipairs(self.names) do
        out.transitions[name]=self.ports[name].transitions-before[name]
        assert(out.transitions[name]<=8,"transition budget")
        assert(out.io_bytes[name]<=512,"byte budget")
    end
    return out
end
function S:next_wait()
    if self.ipc_pending>0 then return 0 end
    local earliest
    local function deadline(d) if d and (not earliest or d<earliest) then earliest=d end end
    for _,name in ipairs(self.names) do
        local t=self.ports[name]
        for _,e in ipairs(self.queues[name]) do deadline(e.expiry) end
        if t.op then
            deadline(t.dop);deadline(t.da)
            if t.state=="setup" then deadline(t.setup_deadline) end
            if t.state=="retry" then deadline(t.retry_at) end
        end
        if t.state=="quarantine" and t.quarantine_end<MAX then
            deadline(math.max(add(t.quarantine_end,1),t.quiet_end))
        end
        if #self.queues[name]>0 and t.state=="idle" and (t.kind=="tcp" or empty(self.pending)) then
            deadline(t.ready_at)
        end
    end
    if not earliest then return nil end
    return math.max(0,math.min(self.quantum,earliest-self.now))
end
return M
