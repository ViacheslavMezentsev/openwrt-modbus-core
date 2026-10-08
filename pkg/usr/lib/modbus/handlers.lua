local M = {}

local function copy(value, depth)
    if type(value) ~= 'table' then return value end
    assert((depth or 0) < 8, 'topic nesting limit')
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v, (depth or 0) + 1) end
    return result
end

local function bounded(fn, ...)
    local previous, mask, count = debug.gethook()
    local ticks = 0
    debug.sethook(function()
        ticks = ticks + 1
        if ticks >= 30 then error('handler instruction budget exceeded') end
    end, '', 1000)
    local ok, result = pcall(fn, ...)
    debug.sethook(previous, mask, count)
    return ok, result
end

function M.new(unit, clock, report)
    local self = {latest = {}, queue = {}, loaded = {}}
    local led = '/devices/' .. unit .. '/system/led'
    local function failure(name, err)
        report({kind='handler_error', handler=name, error=tostring(err):sub(1,256), unit=unit})
    end
    function self:load(path)
        if #self.loaded >= 8 then failure(path, 'handler count limit'); return false end
        local f = io.open(path, 'r')
        if not f then failure(path, 'cannot read handler'); return false end
        local source = f:read(32769)
        f:close()
        if not source or #source > 32768 or source:byte(1) == 27 then
            failure(path, 'handler must be Lua source <=32 KiB'); return false
        end
        local chunk, err = loadstring(source, '@' .. path)
        if not chunk then failure(path, err); return false end
        -- Trusted local scripts, not a security boundary against hostile code.
        setfenv(chunk, {UNIT_ID=unit, assert=assert, error=error, tonumber=tonumber,
            tostring=tostring, type=type, pairs=pairs, ipairs=ipairs,
            math={floor=math.floor, min=math.min, max=math.max, abs=math.abs}})
        local ok, spec = bounded(chunk)
        if not ok or type(spec) ~= 'table' or type(spec.topic) ~= 'string'
            or type(spec.handle) ~= 'function' then
            failure(path, ok and 'expected {topic, handle}' or spec); return false
        end
        self.loaded[#self.loaded+1] = {name=path, topic=spec.topic, handle=spec.handle}
        return true
    end
    function self:observe(topic, event, dispatch)
        if not topic then return end
        self.latest[topic] = {event=copy(event), at=clock()}
        if not dispatch then return end
        for _, h in ipairs(self.loaded) do
            if not h.disabled and h.topic == topic then
                local pending = {}
                local api = {}
                function api.topics()
                    local names = {}
                    for name in pairs(self.latest) do names[#names+1] = name end
                    table.sort(names)
                    return names
                end
                function api.get(name)
                    local item = self.latest[name]
                    if not item then return nil end
                    local value = copy(item.event)
                    value.age = math.max(0, clock() - item.at)
                    return value
                end
                function api.set(name, value)
                    assert(name == led and type(value) == 'boolean', 'write not allowed')
                    local item = self.latest[name]
                    assert(item and item.event.valid and clock() - item.at <= 1,
                        'LED state stale or unavailable')
                    assert(#pending + #self.queue < 8, 'command queue full')
                    pending[#pending+1] = {topic=name, value=value, handler=h.name, at=clock()}
                end
                local ok, err = bounded(h.handle, copy(event), api)
                if ok then
                    for _, command in ipairs(pending) do self.queue[#self.queue+1] = command end
                else
                    h.disabled = true
                    failure(h.name, err)
                end
            end
        end
    end
    function self:take()
        local queue = self.queue
        self.queue = {}
        return queue
    end
    function self:discard() self.queue = {} end
    function self:invalidate()
        self.queue = {}
        for name, item in pairs(self.latest) do
            if name:sub(1,9) == '/devices/' then item.event.valid = false end
        end
    end
    return self
end

return M
