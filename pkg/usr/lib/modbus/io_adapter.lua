-- Core 6.10: isolated injected single-call boundary, NOT a native driver.
local M,A={},{};A.__index=A
local MAX=9007199254740991
local function integer(x,l,h) assert(type(x)=="number" and x==math.floor(x) and x>=l and x<=h,"integer") end
local function plain(x) assert(type(x)=="table" and getmetatable(x)==nil,"plain table") end
local function copy(x) local o={} for k,v in pairs(x) do o[k]=v end return o end
local function token(x)
    plain(x)
    for k in pairs(x) do assert(k=="connection" or k=="operation" or k=="attempt","token field") end
    for _,k in ipairs({"connection","operation","attempt"}) do integer(x[k],1,MAX) end
    return copy(x)
end
local function same(a,b)
    return a and b and a.connection==b.connection and a.operation==b.operation and a.attempt==b.attempt
end
local function later(a,b)
    return not b or a.connection>b.connection or a.connection==b.connection and
        (a.operation>b.operation or a.operation==b.operation and a.attempt>b.attempt)
end
function M.new(sys,cap)
    plain(sys);plain(cap)
    for _,k in ipairs({"clock","open","configure","connect","connect_status","write","read",
        "tx_empty","close","poll","wake","drain_wake"}) do assert(type(sys[k])=="function","primitive "..k) end
    assert(cap.single_call==true and cap.bounded_setup==true and cap.bounded_close==true,"unverified backend")
    assert(type(cap.rtu_tx_complete)=="boolean","TX capability")
    return setmetatable({sys=sys,cap=copy(cap),ports={},count=0,now=0,wake_pending=false},A)
end
function A:_time(out)
    local now=self.sys.clock()
    integer(now,self.now,MAX);self.now=now
    if out then out.clock_reads=out.clock_reads+1 end
    return now
end
function A:capabilities() return copy(self.cap) end
function A:prepare(id,config,tok,deadline)
    assert(type(id)=="string" and #id>0 and #id<=32,"endpoint")
    plain(config);integer(deadline,0,MAX);tok=token(tok)
    for k in pairs(config) do assert(k=="kind" or k=="address" or k=="port" or k=="baud","config field") end
    assert(config.kind=="tcp" or config.kind=="rtu","kind")
    assert(type(config.address)=="string" and #config.address>0 and #config.address<=128,"address")
    if config.kind=="tcp" then integer(config.port,1,65535)
    else integer(config.baud,1,4000000) end -- final serial profile validation belongs to configuration
    if config.kind=="rtu" and not self.cap.rtu_tx_complete then return nil,"tx_completion_unsupported" end
    local old=self.ports[id]
    assert(not old or old.phase=="closed","endpoint busy")
    assert(not old or tok.connection>old.token.connection,"connection token reuse")
    if not old then assert(self.count<7,"endpoint limit");self.count=self.count+1 end
    self.ports[id]={config=copy(config),token=tok,phase="open",deadline=deadline,sent=0,possible=false}
    return true
end
function A:transmit(id,tok,bytes,deadline)
    local p=assert(self.ports[id],"endpoint")
    assert(same(token(tok),p.token) and p.phase=="ready","operation context")
    assert(type(bytes)=="string" and #bytes>=1 and #bytes<=260,"wire buffer")
    integer(deadline,0,p.deadline)
    p.deadline=deadline;p.wire=bytes;p.sent=0;p.possible=false;p.phase="send"
end
function A:finish(id,tok)
    local p=assert(self.ports[id],"endpoint")
    assert(same(token(tok),p.token) and p.phase=="receive","operation context")
    p.wire=nil;p.phase="idle"
end
function A:begin(id,tok,deadline)
    local p=assert(self.ports[id],"endpoint");tok=token(tok);integer(deadline,0,MAX)
    assert(p.phase=="idle" and tok.connection==p.token.connection and later(tok,p.token),"new operation context")
    p.token=tok;p.deadline=deadline;p.sent=0;p.possible=false;p.phase="ready"
end
function A:cancel(id,tok)
    local p=assert(self.ports[id],"endpoint")
    if not same(token(tok),p.token) or p.phase=="closed" or p.phase=="closing" then return false end
    p.failure="cancelled";return true
end
function A:close(id) local p=assert(self.ports[id],"endpoint");p.phase="closing";p.wire=nil end
function A:notify()
    if self.wake_pending then return true end
    -- Producer's one wake attempt. EAGAIN means wake source is already readable.
    local ok,err=self.sys.wake()
    if ok or err=="EAGAIN" then self.wake_pending=true;return true end
    return nil,err
end
local function event(p,id,kind,fields)
    local e={endpoint=id,token=copy(p.token),kind=kind}
    for k,v in pairs(fields or {}) do e[k]=v end
    return e
end
function A:service(id,permit,ready)
    local p=assert(self.ports[id],"endpoint")
    assert(type(permit)=="function","fresh permission callback")
    if ready~=nil then plain(ready);token(ready.token) end
    local out={calls=0,bytes=0,clock_reads=0}
    local function call(name,...)
        assert(out.calls<4,"call budget");out.calls=out.calls+1
        local ok,value,err=pcall(self.sys[name],...)
        self:_time(out)
        if not ok then return nil,"callback_error" end
        return value,err
    end
    local function fail(code)
        p.phase="closing";p.wire=nil
        out.event=event(p,id,"error",{code=code,may_have_sent=p.possible or p.sent>0})
    end
    while out.calls<4 and not out.event do
        local now=self:_time(out)
        if p.phase=="closed" then break end
        if p.phase=="closing" then
            local fd=p.fd;p.fd=nil -- never retry close on a potentially reused Linux fd
            local ok,err=true
            if fd then ok,err=call("close",fd) end
            p.phase="closed";p.wire=nil
            out.event=event(p,id,"closed",{code=not ok and err or nil})
            break
        end
        if p.failure then local code=p.failure;p.failure=nil;fail(code);break end
        if p.phase=="idle" then break end
        if p.blocked_until and now<p.blocked_until then break end
        p.blocked_until=nil
        local authorized=permit(copy(p.token))
        -- Permission callbacks may consume time. Check again directly before I/O.
        now=self:_time(out)
        if now>=p.deadline then fail("expired");break end
        if authorized~=true then fail("revoked");break end
        local phase=p.phase
        local value,err
        if phase=="open" then
            value,err=call("open",copy(p.config))
            if value~=nil then p.fd=value;p.phase=p.config.kind=="rtu" and "configure" or "connect" end
        elseif phase=="configure" then
            value,err=call("configure",p.fd,copy(p.config))
            if value then p.phase="ready" end
        elseif phase=="connect" then
            value,err=call("connect",p.fd,p.config.address,p.config.port)
            if value then p.phase="ready"
            elseif err=="EINPROGRESS" or err=="EINTR" then
                p.phase="connecting";value=false;err=nil
            end
        elseif phase=="connecting" then
            if not ready or not same(ready.token,p.token) or not (ready.writable or ready.error) then break end
            value,err=call("connect_status",p.fd)
            if value then p.phase="ready" end
        elseif phase=="ready" then break
        elseif phase=="send" then
            if not ready or not same(ready.token,p.token) or not ready.writable then break end
            value,err=call("write",p.fd,p.wire:sub(p.sent+1),copy(p.token))
            if err=="callback_error" then p.possible=true end
            if value~=nil then
                integer(value,0,#p.wire-p.sent)
                if value==0 then fail("zero_write");break end
                p.sent=p.sent+value;out.bytes=value
                if p.sent==#p.wire then p.phase="drain" end
                out.event=event(p,id,"tx_progress",{count=value})
            end
        elseif phase=="drain" then
            if p.config.kind=="tcp" then value=true
            else value,err=call("tx_empty",p.fd) end
            if value then p.phase="receive";out.event=event(p,id,"tx_complete") end
        elseif phase=="receive" then
            if not ready or not same(ready.token,p.token) or not (ready.readable or ready.error) then break end
            integer(ready.capacity,0,520)
            if ready.capacity==0 then break end
            value,err=call("read",p.fd,math.min(512,ready.capacity))
            if value~=nil then
                assert(type(value)=="string" and #value<=math.min(512,ready.capacity),"RX primitive contract")
                out.bytes=#value
                if #value==0 and p.config.kind=="tcp" then fail("eof")
                elseif #value>0 then out.event=event(p,id,"rx",{data=value}) end
            end
        else error("phase") end
        -- Preserve transmission accounting, but discard any success at the deadline.
        if self.now>=p.deadline then out.event=nil;fail("expired");break end
        if value==nil and err~="EAGAIN" and err~="EINTR" then fail(err or "io_error");break end
        if err=="EAGAIN" or err=="EINTR" or value==false then
            if phase~="send" and phase~="receive" then p.blocked_until=math.min(MAX,self.now+1) end
            break
        end
        if p.phase=="ready" and phase~="ready" then out.event=event(p,id,"prepared") end
        if phase=="drain" or phase=="receive" then break end
    end
    return out
end
function A:wait(timeout)
    integer(timeout,0,100)
    local now=self:_time();local interests={}
    for id,p in pairs(self.ports) do
        if p.phase~="idle" and p.phase~="closed" then timeout=math.min(timeout,math.max(0,p.deadline-now)) end
        if p.blocked_until then timeout=math.min(timeout,math.max(0,p.blocked_until-now)) end
        if p.failure or p.phase=="closing" or
            ((p.phase=="open" or p.phase=="configure" or p.phase=="connect") and
             (not p.blocked_until or now>=p.blocked_until)) then timeout=0 end
        if p.fd and (p.phase=="connecting" or p.phase=="send" or p.phase=="receive") then
            interests[#interests+1]={endpoint=id,fd=p.fd,token=copy(p.token),
                readable=p.phase=="receive",writable=p.phase=="send" or p.phase=="connecting"}
        end
    end
    local ready,err=self.sys.poll(interests,timeout)
    self:_time()
    if not ready then return nil,err end -- EINTR returns to caller; no hidden retry
    plain(ready)
    local filtered={}
    for id,e in pairs(ready) do
        if id=="wake" then
            self.sys.drain_wake();self.wake_pending=false
        else
            local p=self.ports[id]
            if p and same(e.token,p.token) then filtered[id]=e end
        end
    end
    return filtered
end
return M
