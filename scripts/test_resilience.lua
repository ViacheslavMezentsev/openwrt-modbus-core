package.path = 'pkg/usr/lib/modbus/?.lua;' .. package.path
local Engine = require('handlers')
local System = require('system_io')
local Topics = require('topics')
local dir = assert(arg[1], 'temporary directory required')
local led_topic = '/devices/1/system/led'
local function fixture(name, source)
    local path = dir .. '/resilience-' .. name .. '.lua'
    local f = assert(io.open(path, 'wb'))
    assert(f:write(source)); assert(f:close())
    return path
end

local function bench()
    local b = {now=0, count=0, uptime=1000, led=false, writes=0, coil_reads=0,
        log={}, map={0x5741,2,3}}
    local engine
    local function clock() return b.now end
    local function publish(e)
        b.log[#b.log+1] = e
        engine:observe(Topics.name(e), e, true)
    end
    engine = Engine.new(1, clock, publish)
    assert(engine:load('pkg/etc/modbus-rtu-core/handlers.d/button-led.lua'))
    b.engine = engine
    b.system = System.new(1, engine, publish,
        function(t,e) engine:observe(t,e,false) end, clock)
    b.port = {}
    function b.port:read(unit, fn, address, count)
        assert(unit == 1 and address == 256)
        if fn == 4 then
            assert(count == 8)
            return {b.map[1],b.map[2],b.map[3],0,0,b.count,0,b.uptime}
        end
        assert(fn == 1 and count == 1)
        b.coil_reads = b.coil_reads + 1
        if b.after_write and b.readback == 'error' then return nil, 'readback failed' end
        if b.after_write and b.readback == 'mismatch' then return {b.led and 0 or 1} end
        return {b.led and 1 or 0}
    end
    function b.port:write_coil(unit, address, value)
        assert(unit == 1 and address == 256 and type(value) == 'boolean')
        b.writes, b.led, b.after_write = b.writes+1, value, true
        return true
    end
    function b:step()
        self.after_write = false
        return self.system:step(self.port)
    end
    function b:results()
        local result = {}
        for _, e in ipairs(self.log) do
            if e.kind == 'command_result' then result[#result+1] = e end
        end
        return result
    end
    return b
end

-- TC-26: reject each incompatible field before coil reads or writes.
for field = 1, 3 do
    local b = bench()
    b.map[field] = b.map[field] + 1
    local ok, err = b:step()
    assert(not ok and err == 'unsupported system register map')
    assert(b.writes == 0 and b.coil_reads == 0 and #b:results() == 0)
    assert(b.engine.latest[led_topic].event.valid == false)
    assert(b.engine.latest['/devices/1/system/button'].event.valid == false)
    b.map = {0x5741,2,3}
    b.count = 3
    assert(b:step() and b.writes == 0)
    assert(b.engine.latest['/devices/1/system/button'].event.baseline)
end

-- TC-16: readback failures invalidate state and never replay the write.
for _, failure in ipairs({'mismatch', 'error'}) do
    local b = bench()
    assert(b:step())
    b.now, b.uptime, b.count, b.readback = 0.25, 1250, 1, failure
    local ok, err = b:step()
    assert(not ok and err == (failure == 'error' and 'readback failed' or 'LED readback mismatch'))
    local results = b:results()
    assert(#results == 1 and not results[1].success and results[1].error == err)
    assert(b.writes == 1 and not b.engine.latest[led_topic].event.valid)
    assert(#b.engine:take() == 0)
    b.readback = nil
    assert(b:step() and b.writes == 1 and #b:results() == 1)
end

-- TC-21: age commands after enqueue, not before the freshness check.
for _, age in ipairs({1, 1.001}) do
    local b = bench()
    assert(b:step())
    local take = b.engine.take
    function b.engine:take()
        local queue = take(self)
        if #queue > 0 then b.now = b.now + age end
        return queue
    end
    b.now, b.uptime, b.count = 0.25, 1250, 1
    local ok, err = b:step()
    local results = b:results()
    assert(#results == 1)
    if age == 1 then
        assert(ok and results[1].success and b.writes == 1)
    else
        assert(not ok and err == 'command expired' and not results[1].success)
        assert(results[1].error == err and b.writes == 0)
        assert(not b.engine.latest[led_topic].event.valid and #b.engine:take() == 0)
        assert(b:step() and b.writes == 0 and #b:results() == 1)
    end
end

-- TC-31: quiet reads refresh the snapshot without publishing duplicates.
do
    local b = bench()
    assert(b:step())
    local publications = #b.log
    b.now, b.uptime = 0.25, 1250
    assert(b:step() and #b.log == publications)
    assert(b.engine.latest[led_topic].at == 0.25)
    assert(b.engine.latest['/devices/1/system/button'].at == 0.25)
    b.led = true
    assert(b:step() and #b.log == publications + 1)
end

local now, errors = 0, {}
local function new_engine()
    return Engine.new(1, function() return now end, function(e) errors[#errors+1] = e end)
end
local function load(engine, name, source)
    return engine:load(fixture(name, source))
end

-- TC-20: both callback payloads and ctx.get results are detached snapshots.
do
    local engine = new_engine()
    assert(load(engine, 'api', [[return {topic='z',handle=function(e,ctx)
        local names = ctx.topics()
        assert(#names == 2 and names[1] == 'a' and names[2] == 'z')
        names[1] = 'changed'
        assert(ctx.topics()[1] == 'a' and ctx.get('missing') == nil)
        local item = ctx.get('a')
        assert(item.age == 0.5 and item.nested.value == 7)
        item.nested.value = 99
        assert(ctx.get('a').nested.value == 7)
        e.nested.value = 100
        assert(ctx.get('z').nested.value == 3)
    end}]]))
    local source = {nested={value=7}}
    engine:observe('a', source, false)
    source.nested.value = 88
    now = 0.5
    engine:observe('z', {nested={value=3}}, true)
    assert(not engine.loaded[1].disabled and engine.latest.a.event.nested.value == 7)
    assert(engine.latest.z.event.nested.value == 3)
end

-- TC-18/19: bad callback/type cannot cancel a healthy neighbor's commands.
do
    local engine = new_engine()
    assert(load(engine, 'bad-type', [[return {topic='go',handle=function(e,ctx)
        ctx.set('/devices/1/system/led',true)
        ctx.set('/devices/1/system/led',1)
    end}]]))
    assert(load(engine, 'healthy', [[return {topic='go',handle=function(e,ctx)
        ctx.set('/devices/1/system/led',false)
    end}]]))
    engine:observe(led_topic, {valid=true,value=true}, false)
    local before = #errors
    for _ = 1, 2 do
        engine:observe('go', {}, true)
        local queue = engine:take()
        assert(#queue == 1 and queue[1].value == false)
    end
    assert(engine.loaded[1].disabled and not engine.loaded[2].disabled)
    assert(#errors == before+1 and errors[#errors].kind == 'handler_error')
    assert(errors[#errors].error:find('write not allowed', 1, true))
end

-- TC-19: a full accepted queue remains intact when another callback overflows.
do
    local engine = new_engine()
    assert(load(engine, 'fill', [[return {topic='go',handle=function(e,ctx)
        for i=1,8 do ctx.set('/devices/1/system/led',true) end
    end}]]))
    assert(load(engine, 'overflow', [[return {topic='go',handle=function(e,ctx)
        ctx.set('/devices/1/system/led',false)
    end}]]))
    engine:observe(led_topic, {valid=true,value=false}, false)
    engine:observe('go', {}, true)
    assert(not engine.loaded[1].disabled and engine.loaded[2].disabled)
    local queue = engine:take()
    assert(#queue == 8)
    for _, command in ipairs(queue) do assert(command.value == true) end
end

-- TC-28: exact source/count limits, oversized source and binary chunks.
do
    local engine = new_engine()
    local source = "return {topic='test',handle=function() end}\n--"
    assert(load(engine, 'exact-source', source .. string.rep('x', 32768-#source)))
    assert(not load(engine, 'large-source', source .. string.rep('x', 32769-#source)))
    assert(not load(engine, 'binary', string.dump(function() end)))
    assert(not load(engine, 'invalid-spec', 'return {topic=1}'))
    assert(#engine.loaded == 1)
    for i=2,8 do assert(load(engine, 'limit-' .. i, source)) end
    assert(not load(engine, 'ninth', source) and #engine.loaded == 8)
    engine:observe('test', {}, true)
    for _, handler in ipairs(engine.loaded) do assert(not handler.disabled) end
end
assert(debug.gethook() == nil, 'instruction hook leaked')
print('[test_resilience] OK: map, readback, TTL, snapshots, isolation, handler limits')
