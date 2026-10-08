package.path = 'pkg/usr/lib/modbus/?.lua;' .. package.path
local Engine = require('handlers')
local System = require('system_io')
local Topics = require('topics')
local dir = assert(arg[1], 'temporary directory required')
local now, log, writes = 0, {}, {}
local counter, uptime, pressed, led = 0, 1000, false, false
local fail_read, fail_write = false, false
local engine
local function emit(e)
    log[#log+1] = e
    if engine then engine:observe(Topics.name(e), e, true) end
end
local function clock() return now end
engine = Engine.new(1, clock, emit)
assert(engine:load('pkg/etc/modbus-rtu-core/handlers.d/button-led.lua'))
local sys = System.new(1, engine, emit, function(t,e) engine:observe(t,e,false) end, clock)
local port = {}
function port:read(_, fn)
    if fail_read then return nil, 'disconnected' end
    if fn == 4 then
        return {0x5741,2,3,pressed and 1 or 0,math.floor(counter/65536),counter%65536,
            math.floor(uptime/65536),uptime%65536}
    end
    return {led and 1 or 0}
end
function port:write_coil(_, address, value)
    assert(address == 256)
    writes[#writes+1] = value
    if fail_write then led=value; return nil, 'lost acknowledgement' end
    led = value
    return true
end
local function step(delta, down)
    now, uptime = now+0.2, (uptime+200)%4294967296
    counter = (counter + delta)%4294967296
    pressed = down
    return sys:step(port)
end
assert(step(0,false) and #writes == 0)
assert(step(1,true) and led and #writes == 1)
assert(step(0,true) and #writes == 1)
assert(step(0,false) and #writes == 1)
assert(step(2,false) and led and #writes == 1) -- even burst preserves final state
assert(step(1,false) and not led and #writes == 2)
fail_read = true
assert(not step(0,false))
counter = counter + 3
fail_read = false
assert(step(0,false) and #writes == 2) -- reconnect baseline
counter, uptime = 0, 0
assert(step(0,false) and #writes == 2) -- reboot baseline
counter, uptime = 4294967295, 4294967200
sys:invalidate('test wrap baseline')
assert(sys:step(port))
assert(step(1,true) and led and #writes == 3) -- both uint32 wraps
fail_write = true
assert(not step(1,false) and #writes == 4)
fail_write = false
assert(step(0,false) and #writes == 4) -- no replay after ambiguous write
assert(engine.latest['/devices/1/system/led'].event.valid)

local function fixture(name, source)
    local path = dir .. '/' .. name .. '.lua'
    local f = assert(io.open(path,'w')); f:write(source); f:close()
    return path
end
local bad = Engine.new(1, clock, function(e) log[#log+1]=e end)
assert(not bad:load(fixture('infinite_load','while true do end')))
assert(bad:load(fixture('rollback', [[return {topic='test',handle=function(e,ctx)
ctx.set('/devices/1/system/led',true); error('rollback') end}]])))
bad:observe('/devices/1/system/led',{valid=true,value=false},false)
bad:observe('test',{},true)
assert(#bad:take() == 0 and bad.loaded[1].disabled)
assert(bad:load(fixture('infinite', [[return {topic='loop',handle=function() while true do end end}]])))
bad:observe('loop',{},true)
assert(bad.loaded[2].disabled)
assert(bad:load(fixture('forbidden', [[return {topic='deny',handle=function(e,ctx) ctx.set('/arbitrary',true) end}]])))
bad:observe('deny',{},true)
assert(bad.loaded[3].disabled and #bad:take()==0)
assert(bad:load(fixture('stale', [[return {topic='stale',handle=function(e,ctx) ctx.set('/devices/1/system/led',true) end}]])))
now = now+2
bad:observe('stale',{},true)
assert(bad.loaded[4].disabled)
assert(bad:load(fixture('queue', [[return {topic='queue',handle=function(e,ctx)
for i=1,9 do ctx.set('/devices/1/system/led',true) end end}]])))
bad:observe('/devices/1/system/led',{valid=true,value=false},false)
bad:observe('queue',{},true)
assert(bad.loaded[5].disabled and #bad:take()==0)
local hook = debug.gethook()
assert(hook == nil, 'instruction hook leaked into daemon')
print('[test_handlers] OK: presses, bursts, reconnect, reboot, wrap, lost ACK, budgets, queue, stale state')
