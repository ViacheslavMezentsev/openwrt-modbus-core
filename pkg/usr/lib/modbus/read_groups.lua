-- Core 4.7/6.9: safe FIFO plans, lazy wire requests, packed assembly payload.
local M={}
local function copy(t) local v={} for k,x in pairs(t) do v[k]=x end return v end
function M.size(fc,n) return fc==6 and 0 or fc<=2 and math.ceil(n/8) or n*2 end
function M.locate(profile,q)
    for i=1,profile:count() do
        local r=profile:range(i)
        if r["function"]==q["function"] and r.start<=q.address
            and q.address+q.count<=r.start+r.count then return r,i end
    end
    error("read outside a single declared range")
end
function M.authorize(profile,q)
    local r=M.locate(assert(profile,"missing device profile"),q)
    assert(M.size(q["function"],q.count)<=1024,"result limit")
    assert(math.ceil(q.count/r.max_count)<=16,"fragment limit")
    assert(q.count<=r.max_count or r.safe_read,"unsafe split")
    q.safe_read=r.safe_read
    return q
end
function M.plan(queue,profile)
    local first=queue[1];local q=first.request
    local g={entries={first},start=first.admitted,expiry=first.expiry,
        address=q.address,count=q.count,limit=q.count}
    if q["function"]==6 or not profile then return g end
    local region,index=M.locate(profile,q)
    local low,high=q.address,q.address+q.count
    g.limit=region.max_count
    if not first.readback and region.mergeable and q.count<=region.max_count then
        for i=2,math.min(#queue,16) do
            local e=queue[i];local c=e.request
            if e.readback or c["function"]~=q["function"] or c.device_id~=q.device_id
                or c.unit~=q.unit or c.safe_read~=q.safe_read then break end
            local _,ci=M.locate(profile,c)
            if ci~=index then break end
            local l,h=math.min(low,c.address),math.max(high,c.address+c.count)
            if math.max(0,c.address-high,low-c.address-c.count)>region.max_gap
                or h-l>region.max_count then break end
            g.entries[#g.entries+1]=e;low,high=l,h
            g.start=math.min(g.start,e.admitted);g.expiry=math.min(g.expiry,e.expiry)
        end
    end
    g.address,g.count=low,high-low
    return g
end
local pools=setmetatable({}, {__mode="k"})
function M.is_pool(p) return pools[p]==true end
function M.pool(limit)
    if limit==nil then limit=8192 end
    assert(type(limit)=="number" and limit==math.floor(limit) and limit>=1 and limit<=8192,"pool limit")
    local used,reservations=0,{}
    local p={}
    function p:used() return used end
    function p:acquire(owner,size)
        assert(owner~=nil and reservations[owner]==nil,"reservation owner")
        assert(type(size)=="number" and size==math.floor(size) and size>=0 and size<=1024,"reservation size")
        if used+size>limit then return false end
        reservations[owner]=size;used=used+size;return true
    end
    function p:release(owner)
        assert(reservations[owner]~=nil,"unknown reservation")
        used=used-reservations[owner];reservations[owner]=nil
    end
    pools[p]=true;return p
end
local A={};A.__index=A
function M.assembly(g)
    return setmetatable({group=g,index=0,buffer="",bits=0,attempts=0,sent_attempts=0},A)
end
function A:wire()
    local g=self.group;local q=copy(g.entries[1].request)
    if q["function"]~=6 then
        q.address=g.address+self.index*g.limit
        q.count=math.min(g.limit,g.count-self.index*g.limit)
    end
    return q
end
local function bit(data,i) return math.floor(data:byte(math.floor(i/8)+1)/2^(i%8))%2 end
local function packed(count,get)
    local bytes={}
    for base=0,count-1,8 do
        local v=0
        for j=0,math.min(7,count-base-1) do v=v+get(base+j)*2^j end
        bytes[#bytes+1]=string.char(v)
    end
    return table.concat(bytes)
end
function A:finish(result)
    assert(not self.done,"assembly finished")
    self.attempts=self.attempts+result.attempts
    self.sent_attempts=self.sent_attempts+result.sent_attempts
    local q=self:wire();local g=self.group
    if result.outcome=="ok" and q["function"]~=6 then
        if q["function"]<=2 then
            -- Retain packed strings only; at most one wire-sized temporary byte table.
            local prefix=math.floor(self.bits/8)*8
            local old,oldbits=self.buffer,self.bits
            self.buffer=old:sub(1,prefix/8)..packed(oldbits-prefix+q.count,function(i)
                i=i+prefix
                if i<oldbits then return bit(old,i) end
                return bit(result.data,i-oldbits)
            end)
            self.bits=oldbits+q.count
        else self.buffer=self.buffer..result.data end
        if (self.index+1)*g.limit<g.count then self.index=self.index+1;return {} end
    end
    self.done=true
    local outputs={}
    for _,e in ipairs(g.entries) do
        local req=e.request;local out=copy(result)
        out.operation_id,out.device_id,out.start=req.operation_id,req.device_id,e.admitted
        out.attempts,out.sent_attempts=self.attempts,self.sent_attempts
        if out.outcome=="expired" and self.sent_attempts>0 then out.outcome="timeout" end
        out.data=""
        if out.outcome=="ok" then
            local offset=req.address-g.address
            if req["function"]==6 then out.data=result.data
            elseif req["function"]<=2 then
                out.data=packed(req.count,function(i) return bit(self.buffer,offset+i) end)
            else out.data=self.buffer:sub(offset*2+1,(offset+req.count)*2) end
        end
        outputs[#outputs+1]=out
    end
    self.buffer=""
    return outputs
end
return M
