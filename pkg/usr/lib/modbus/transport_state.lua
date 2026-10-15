-- Core 6.8: isolated state engine. No serial/socket, sleeps or wall clock.
local rtu = require("modbus.rtu")
local M, T = {}, {}
T.__index = T
local MAX = 9007199254740991
local function int(n,lo,hi,name)
    assert(type(n)=="number" and n==math.floor(n) and n>=lo and n<=hi,name or "integer")
    return n
end
local function add(a,b) return a > MAX-b and MAX or a+b end
local function u16(n) return string.char(math.floor(n/256),n%256) end
local function get16(s,i) return s:byte(i)*256+s:byte(i+1) end
local function plain(t) assert(type(t)=="table" and getmetatable(t)==nil,"plain table") end
local function text(s) return type(s)=="string" and #s>0 end
local function copy(t) local out={};for k,v in pairs(t) do out[k]=v end;return out end
local function pdu(q) return string.char(q["function"])..u16(q.address)..u16(q.count) end
function M.tcp_frame(tid,unit,data)
    return u16(tid)..u16(0)..u16(#data+1)..string.char(unit)..data
end
M.rtu_frame, M.crc = rtu.frame, rtu.crc
function M.silence_ms(baud)
    assert(baud==9600 or baud==19200 or baud==38400 or baud==57600 or baud==115200,"baud")
    return baud<=19200 and math.ceil(35000/baud) or 2
end
local defaults={request_timeout=500,operation_timeout=10000,setup_timeout=1000,
    retries=0,retry_delay=100,reconnect_delay=1000,policy="manual",baud=115200,
    transport_id="line"}
function M.new(kind,options,clock)
    assert(kind=="rtu" or kind=="tcp","transport kind")
    if options==nil then options={} end;plain(options)
    local cfg=copy(defaults)
    for k,v in pairs(options) do
        assert(defaults[k]~=nil or k=="late_bound" or k=="timing_profile","unknown option")
        cfg[k]=v
    end
    int(cfg.request_timeout,100,2000);int(cfg.operation_timeout,cfg.request_timeout,60000)
    int(cfg.setup_timeout,100,5000);int(cfg.retries,0,3);int(cfg.retry_delay,0,5000)
    int(cfg.reconnect_delay,1000,30000)
    assert(text(cfg.transport_id),"transport identity")
    assert(cfg.policy=="manual" or cfg.policy=="bounded","policy")
    if cfg.policy=="bounded" then
        int(cfg.late_bound,1,60000)
        assert(text(cfg.timing_profile) and cfg.timing_profile:match("%S"),"timing evidence")
    else assert(cfg.late_bound==nil and cfg.timing_profile==nil,"unused timing profile") end
    assert(clock==nil or type(clock)=="function","clock")
    local self=setmetatable(cfg,T)
    self.kind,self.clock,self.now=kind,clock,0
    self.gap=M.silence_ms(cfg.baud)
    self.state=kind=="rtu" and "desynchronized" or "idle"
    self.transitions=1
    self.results,self.samples={},{}
    self.generation,self.next_tid,self.ready_at=0,0,0
    self.connected=false
    self.rx,self.wire="",""
    self.quarantine_end,self.quiet_end=0,0
    return self
end
function T:_state(s)
    if self.state~=s then self.transitions=self.transitions+1;self.state=s end
end
function T:_service() self:tick(self.clock and self.clock() or self.now) end
function T:_callback(gen) return self.kind~="tcp" or gen==self.generation end
function T:_event(gen)
    if not self:_callback(gen) then return false end
    self:_service()
    return self:_callback(gen)
end
function T:_valid(value)
    if self.current_device then
        self.samples[self.current_device].valid=value
        self.valid=value
    end
end
function T:confirm_sync(evidence)
    assert(self.kind=="rtu" and not self.op and text(evidence) and evidence:match("%S"),"idle sync evidence")
    self:_service()
    self.sync_evidence=evidence;self:_state("idle")
    self.rx="";self.ready_at=add(self.now,self.gap)
end
-- Shared pure validation/copy for scheduler admission and individual states.
function M.validate_request(request,kind,logical)
    assert(kind=="rtu" or kind=="tcp","transport kind")
    plain(request)
    local q=copy(request)
    local allowed={operation_id=true,device_id=true,unit=true,["function"]=true,
                   address=true,count=true,safe_read=true}
    for k in pairs(q) do assert(allowed[k],"request field") end
    assert(text(q.operation_id) and text(q.device_id),"request identity")
    if q.unit==nil then q.unit=1 end
    if q["function"]==nil then q["function"]=3 end
    if q.address==nil then q.address=0 end
    if q.count==nil then q.count=1 end
    if q.safe_read==nil then q.safe_read=false end
    int(q.unit,kind=="rtu" and 1 or 0,kind=="rtu" and 247 or 255)
    local fc=q["function"]
    assert(fc==1 or fc==2 or fc==3 or fc==4 or fc==6,"reads or FC06 probe only")
    int(q.address,0,65535)
    int(q.count,fc==6 and 0 or 1,fc==6 and 65535 or logical and (fc<=2 and 8192 or 512) or fc<=2 and 2000 or 125)
    assert(fc==6 or q.address+q.count<=65536,"read range")
    assert(type(q.safe_read)=="boolean" and not (fc==6 and q.safe_read),"safe_read")
    return q
end
function T:admit(request,expiry,admitted_at)
    self:_service()
    if self.op or #self.results>0 or self.state=="quarantine" then return false end
    local q=M.validate_request(request,self.kind)
    if expiry~=nil then int(expiry,0,MAX) end
    local start=admitted_at
    if start==nil then start=self.now end
    int(start,0,self.now)
    if not self.samples[q.device_id] then
        local n=0;for _ in pairs(self.samples) do n=n+1 end
        assert(n<32,"device limit")
        self.samples[q.device_id]={valid=false}
    end
    self.current_device=q.device_id
    self.valid=self.samples[q.device_id].valid
    self.last_success=self.samples[q.device_id].last_success
    self.op,self.start=q,start
    self.dop=math.min(add(start,self.operation_timeout),expiry or MAX)
    self.attempts,self.sent_attempts,self.sent,self.total_sent=0,0,0,0
    self.da=nil;self.rx=""
    if self.state~="desynchronized" then self:_state("queued") end
    return true
end
function T:begin()
    self:_service()
    if not self.op or self.state~="queued" or self.now<self.ready_at then return false end
    self:_setup();return true
end
function T:_setup()
    self.attempts=self.attempts+1;self.sent=0;self.tx_finished=false
    self.da=nil;self.rx="";self:_state("setup")
    self.setup_deadline=math.min(self.dop,add(self.now,self.setup_timeout))
    if self.kind=="tcp" and (not self.connected or self.next_tid>65535) then
        self.generation=self.generation+1;self.next_tid=0;self.connected=false
    end
end
function T:setup_done(gen)
    if not self:_event(gen) or self.state~="setup" or not self.op then return end
    if self.kind=="tcp" then
        self.connected=true;self.tid=self.next_tid;self.next_tid=self.next_tid+1
        self.wire=M.tcp_frame(self.tid,self.op.unit,pdu(self.op))
    else self.wire=rtu.frame(string.char(self.op.unit)..pdu(self.op)) end
    self:_state("send")
end
function T:tx(count,gen)
    if not self:_event(gen) or not self.op or self.state~="send" then return end
    int(count,0,#self.wire-self.sent,"TX count")
    if not self.da then self.da=math.min(self.dop,add(self.now,self.request_timeout)) end
    if count>0 then
        if self.sent==0 then self.sent_attempts=self.sent_attempts+1 end
        self.sent=self.sent+count;self.total_sent=self.total_sent+count;self.last_write=self.now
    end
    if self.sent==#self.wire then self:_state("tx_completion") end
end
function T:tx_complete(gen)
    if not self:_event(gen) then return end
    if self.op and self.state=="tx_completion" then
        self:_state("receive");self.tx_finished=true
        if self.kind=="rtu" then self.ready_at=add(self.now,self.gap) end
    end
end
function T:_close()
    self.generation=self.generation+1;self.connected=false;self.rx=""
    self.ready_at=math.max(self.ready_at,add(self.now,self.reconnect_delay))
end
function T:_finish(outcome,exception,data)
    if not self.op then return end
    local op=self.op
    local write
    if op["function"]==6 then
        write=outcome=="ok" and "confirmed" or self.total_sent>0 and "unknown" or "not_sent"
    end
    self.results[1]={operation_id=op.operation_id,device_id=op.device_id,
        transport_id=self.transport_id,outcome=outcome,attempts=self.attempts,
        sent_attempts=self.sent_attempts,start=self.start,["end"]=self.now,
        write_outcome=write,exception_code=exception,data=data or ""}
    self:_valid(outcome=="ok")
    if self.valid then
        self.last_success=self.now;self.samples[self.current_device].last_success=self.now
    end
    self.op=nil;self.da=nil;self.rx=""
    if self.state~="quarantine" and self.state~="desynchronized" then self:_state("idle") end
end
function T:_fail(outcome,retryable)
    if not self.op then return end
    self:_valid(false)
    if self.kind=="tcp" then self:_close()
    elseif self.sent>0 then
        if self.policy=="bounded" and self.sent==#self.wire and self.tx_finished then
            self:_state("quarantine")
            self.quarantine_end=add(self.last_write,self.late_bound)
            self.quiet_end=math.max(add(self.now,self.gap),self.ready_at)
        else self:_state("desynchronized") end
    end
    self.rx=""
    local eligible=retryable and self.op.safe_read and self.op["function"]<=4
        and self.attempts<=self.retries and self.now<self.dop and self.state~="desynchronized"
    if eligible then
        self.retry_at=math.max(add(self.now,self.retry_delay),self.ready_at)
        if self.state~="quarantine" then self:_state("retry") end
        self.da=nil
    else self:_finish(outcome) end
end
function T:tick(now)
    int(now,self.now,MAX,"monotonic clock");self.now=now
    if self.op and now>=self.dop then self:_fail(self.total_sent>0 and "timeout" or "expired")
    elseif self.op and self.da and now>=self.da then self:_fail("timeout",true)
    elseif self.op and self.state=="setup" and now>=self.setup_deadline then self:_fail("timeout",true) end
    if self.state=="quarantine" and now>self.quarantine_end and now>=self.quiet_end then
        self:_state(self.op and "retry" or "idle")
        if not self.op then self.ready_at=now end
    end
    if self.op and self.state=="retry" and now>=self.retry_at then self:_setup() end
end
function T:io_error(gen)
    if not self:_event(gen) then return end
    if self.state=="setup" or self.state=="send" or self.state=="tx_completion" or self.state=="receive" then
        self:_fail("io_error",true)
    end
end
function T:cancel() self:_service();self:_fail("cancelled") end
function T:receive(data,gen)
    if not self:_callback(gen) then return end
    assert(type(data)=="string" and #data<=512,"bounded byte event")
    if not self:_event(gen) then return end
    if #data==0 then
        if self.kind=="tcp" then self:io_error(gen) end
        return
    end
    if self.state=="quarantine" then
        if self.now>self.quarantine_end then
            self:_state("desynchronized");self:_finish("desynchronized")
        else self.quiet_end=add(self.now,self.gap) end
        return
    end
    if self.kind=="rtu" and self.state=="desynchronized" then return end
    if self.state~="receive" or not self.op then
        if self.kind=="tcp" then self:_close();self:_finish("protocol_error")
        else self:_state("desynchronized");self:_finish("desynchronized") end
        self:_valid(false);return
    end
    if #self.rx+#data>(self.kind=="tcp" and 520 or 256) then
        self:_fail("protocol_error",self.kind=="rtu");return
    end
    self.rx=self.rx..data
    if self.kind=="tcp" then self:_parse_tcp()
    else self.ready_at=add(self.now,self.gap);self:_parse_rtu() end
end
function T:_parse_tcp()
    if #self.rx<7 then return end
    local tid,protocol,len,unit=get16(self.rx,1),get16(self.rx,3),get16(self.rx,5),self.rx:byte(7)
    if protocol~=0 or len<2 or len>254 or tid~=self.tid or unit~=self.op.unit then
        self:_fail("protocol_error");return
    end
    local size=6+len
    if #self.rx<size then return end
    local extra=#self.rx>size
    self:_pdu(self.rx:sub(8,size))
    if extra then self:_close() end
end
function T:_parse_rtu()
    if #self.rx<3 then return end
    local unit,fc=self.rx:byte(1,2)
    if unit~=self.op.unit or (fc~=self.op["function"] and fc~=self.op["function"]+128) then
        self:_fail("protocol_error",true);return
    end
    local size=fc>=128 and 5 or fc==6 and 8 or 5+self.rx:byte(3)
    if size>256 then self:_fail("protocol_error",true);return end
    if #self.rx<size then return end
    local frame=self.rx:sub(1,size)
    if rtu.crc(frame)~=0 then self:_fail("protocol_error",true);return end
    local extra=#self.rx>size
    self:_pdu(frame:sub(2,-3))
    if extra then self:_state("desynchronized");self:_valid(false) end
end
function T:_pdu(data)
    local fc=self.op["function"]
    if #data==2 and data:byte(1)==fc+128 and data:byte(2)~=0 then
        self:_finish("modbus_exception",data:byte(2));return
    end
    local good
    if fc==6 then good=data==pdu(self.op)
    else
        local n=fc<=2 and math.ceil(self.op.count/8) or self.op.count*2
        good=#data==n+2 and data:sub(1,2)==string.char(fc,n)
    end
    if good then self:_finish("ok",nil,data:sub(3))
    else self:_fail("protocol_error",self.kind=="rtu") end
end
function T:drain_results() local out=self.results;self.results={};return out end
return M
