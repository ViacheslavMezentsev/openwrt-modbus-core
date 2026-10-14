-- Core TC-123/124/127/129: isolated Lua schema and transactional publication.
package.path = "./pkg/usr/lib/?.lua;" .. package.path
local loader = require("modbus.device_profiles")
local encoder = require("modbus.json")
local tests = 0
local function test(name, fn)
    fn(); tests=tests+1; print("[lua-profiles] OK " .. name)
end
local function document(id, ranges)
    return encoder.encode({id=id, read_ranges=ranges or {{["function"]=3,start=0,count=4}}})
end
local function valid(text, id)
    local value,err=loader.decode(text,id or "p")
    assert(value and not err, err and err.code)
    return value
end
local function bad(text, code, id)
    local value,err=loader.decode(text,id or "p")
    assert(not value and type(err)=="table")
    if code then assert(err.code==code, err.code .. " != " .. code) end
end
local function rejected(store, bindings, code, maintenance, active)
    local old=store:current()
    if maintenance==nil then maintenance=true end
    if active==nil then active=0 end
    local value,err=store:activate(bindings,maintenance,active)
    assert(not value and err.code==code, err and err.code)
    assert(store:current()==old)
end
local function ranges(n)
    local result={}
    for i=1,n do result[i]={["function"]=3,start=i-1,count=1} end
    return result
end
test("defaults and defensive range copies",function()
    local p=valid(document("p"))
    local a=p:range(1)
    assert(p:id()=="p" and p:count()==1 and a.max_count==1 and a.max_gap==0)
    assert(a.safe_read==false and a.mergeable==false)
    a.start=200
    assert(p:range(1).start==0)
    assert(not pcall(function() p.count=0 end))
    local x,e=p:range(0); assert(not x and e.code=="range_index")
end)
test("root array null and required fields",function()
    for _,s in ipairs({'[]','null','false','{}','{"id":"p"}',
      '{"id":"p","read_ranges":{}}','{"id":"p","read_ranges":[]}',
      '{"id":"p","read_ranges":[null]}','{"id":"p","read_ranges":[[]]}'}) do bad(s) end
end)
test("unknown fields and missing range fields",function()
    bad('{"id":"p","extra":0,"read_ranges":[{"function":3,"start":0,"count":1}]}',"field")
    for _,field in ipairs({"function","start","count"}) do
        local a=ranges(1);a[1][field]=nil;bad(document("p",a))
    end
    local a=ranges(1);a[1].write=true;bad(document("p",a),"field")
end)
test("canonical identifiers and filename match",function()
    for _,id in ipairs({"","../p","/p","P","p.json","a/b","a b",string.rep("a",33)}) do
        bad(document(id),nil,id);bad(document(id))
    end
    valid(document(string.rep("a",32)),string.rep("a",32))
    valid(document("a-0_x"),"a-0_x")
    bad(document("q"),"profile_id")
end)
test("duplicates escaped aliases and nesting",function()
    bad('{"id":"p","id":"p","read_ranges":[]}',"json_duplicate_key")
    bad([=[{"id":"p","read_ranges":[{"function":3,"start":0,"\u0073tart":1,"count":1}]}]=],"json_duplicate_key")
    bad('{"id":"p","read_ranges":[{"function":3,"start":0,"count":1,"x":{}}]}',"json_depth")
end)
test("integer syntax rejects exponent fraction boolean null",function()
    for _,value in ipairs({"0.0","0e0","false","null",'"0"'}) do
        bad('{"id":"p","read_ranges":[{"function":3,"start":'..value..',"count":1}]}',"integer_start")
    end
end)
test("numeric boundaries and flags",function()
    valid(document("p",{{["function"]=1,start=65535,count=1,max_count=2000},
                        {["function"]=4,start=0,count=65536,max_count=125,max_gap=65535}}))
    for field,values in pairs({["function"]={0,5},start={-1,65536},count={0,65537},
                               max_count={0,126},max_gap={-1,1}}) do
        for _,value in ipairs(values) do local a=ranges(1);a[1][field]=value;bad(document("p",a)) end
    end
    local a=ranges(1);a[1].start=65535;a[1].count=2;bad(document("p",a))
    for _,field in ipairs({"safe_read","mergeable"}) do
        local a=ranges(1);a[1][field]=1;bad(document("p",a),"boolean_"..field)
    end
    local a=ranges(1);a[1].mergeable=true;bad(document("p",a),"unsafe_merge")
    a[1].safe_read=true;valid(document("p",a))
end)
test("sorted ranges overlap adjacency and separate functions",function()
    local a={{["function"]=3,start=4,count=2},{["function"]=3,start=0,count=4},
             {["function"]=2,start=0,count=6}}
    local p=valid(document("p",a));assert(p:range(1)["function"]==2 and p:range(2).start==0)
    a[1].start=3;bad(document("p",a),"overlap")
    a[1].start=0;bad(document("p",a),"overlap")
end)
test("profile range and byte boundaries",function()
    valid(document("p",ranges(64)))
    bad(document("p",ranges(65)),"ranges")
    local s=document("p");valid(s..string.rep(" ",16384-#s))
    bad(s..string.rep(" ",16385-#s),"json_bytes")
end)
test("reader mandatory and cold failure",function()
    local x,e=loader.new();assert(not x and e.code=="reader_required")
    local store=assert(loader.new(function() return nil,"missing" end))
    rejected(store,{d="p"},"read")
    assert(#store:current():devices()==0)
end)
test("only selected profiles loaded once with bounded read request",function()
    local seen={}
    local store=assert(loader.new(function(id,n)
        assert(n==16385);seen[id]=(seen[id] or 0)+1;return document(id)
    end))
    local view=assert(store:activate({a="p",b="p",c="q"},true,0))
    assert(seen.p==1 and seen.q==1 and view:profile_count()==2 and view:range_count()==2)
    assert(view:profile("a")==view:profile("b") and view:profile("a")~=view:profile("c"))
    assert(view:binding("a")=="p" and view:profile("missing")==nil)
end)
test("bindings validated before I/O",function()
    local reads=0
    local store=assert(loader.new(function(id) reads=reads+1;return document(id) end))
    rejected(store,{["../d"]="p"},"binding_id")
    rejected(store,{d="../p"},"binding_id")
    rejected(store,setmetatable({d="p"},{}),"bindings")
    rejected(store,false,"bindings")
    local b={};for i=1,33 do b["d"..i]="p" end
    rejected(store,b,"device_limit")
    b={};for i=1,17 do b["d"..i]="p"..i end
    rejected(store,b,"profile_limit")
    assert(reads==0)
end)
test("maintenance assertions and busy operations",function()
    local reads=0
    local store=assert(loader.new(function(id) reads=reads+1;return document(id) end))
    rejected(store,{d="p"},"maintenance",false,0)
    rejected(store,{d="p"},"maintenance",true,1)
    rejected(store,{d="p"},"maintenance",true,"0")
    assert(reads==0)
end)
test("device and unique profile exact boundaries",function()
    local store=assert(loader.new(function(id) return document(id) end))
    local b={};for i=1,32 do b["d"..i]="p"..((i-1)%16) end
    local v=assert(store:activate(b,true,0))
    assert(#v:devices()==32 and v:profile_count()==16)
end)
test("aggregate ranges counted once and plus one rejected",function()
    local store=assert(loader.new(function(id) return document(id,ranges(id=="p5" and 1 or 64)) end))
    local b={a="p1",b="p2",c="p3",d="p4",e="p1"}
    assert(store:activate(b,true,0):range_count()==256)
    b.f="p5";rejected(store,b,"total_ranges")
end)
test("failed late candidate preserves identity",function()
    local broken=false
    local store=assert(loader.new(function(id)
        if broken and id=="z" then return '{"id":' end
        return document(id)
    end))
    local old=assert(store:activate({d="p"},true,0));local p=old:profile("d")
    broken=true;rejected(store,{a="a",z="z"},"json_value")
    assert(store:current():profile("d")==p)
end)
test("reader failures and oversized response preserve state",function()
    local mode=0
    local store=assert(loader.new(function(id)
        if mode==1 then error("I/O failure") end
        if mode==2 then return {} end
        if mode==3 then return string.rep(" ",16385) end
        return document(id)
    end))
    assert(store:activate({d="p"},true,0))
    for i=1,3 do mode=i;rejected(store,{d="p"},i==3 and "json_bytes" or "read") end
    mode=0;assert(store:activate({d="q"},true,0))
end)
test("input mutation snapshots and retained old view",function()
    local b={d="p"}
    local store=assert(loader.new(function(id) b.d="q";return document(id) end))
    local old=assert(store:activate(b,true,0));assert(old:binding("d")=="p")
    local names=old:devices();names[1]="changed";assert(old:devices()[1]=="d")
    local next=assert(store:activate(b,true,0))
    assert(next:binding("d")=="q" and old:binding("d")=="p")
    assert(store:activate({},true,0):profile_count()==0)
    assert(old:profile("d"):id()=="p")
end)
test("recursive activation rejected without losing outer candidate",function()
    local store
    store=assert(loader.new(function(id)
        rejected(store,{},"busy")
        return document(id)
    end))
    assert(store:activate({d="p"},true,0):binding("d")=="p")
end)
print("[test_device_profiles_lua] OK: "..tests.." cases")
