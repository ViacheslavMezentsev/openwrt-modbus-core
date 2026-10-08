local json = require('json')
local M = {}

function M.clock()
    local f = assert(io.open('/proc/uptime', 'r'))
    local value = assert(tonumber(f:read('*l'):match('^[%d.]+')))
    f:close()
    return value
end

function M.name(event)
    if event.kind == 'daemon_heartbeat' then return '/core/heartbeat' end
    if event.unit and event.kind == 'device_sample' then
        return '/devices/' .. tostring(event.unit) .. '/sample'
    end
    if event.unit and event.kind == 'device_status' then
        return '/devices/' .. tostring(event.unit) .. '/status'
    end
end

function M.registry(unit, poll_interval, heartbeat_interval)
    local result = {['/core/heartbeat'] = {interval = heartbeat_interval}}
    if unit then
        result['/devices/' .. tostring(unit) .. '/sample'] = {interval = poll_interval}
        result['/devices/' .. tostring(unit) .. '/status'] = {interval = 0}
    end
    return result
end

function M.note(registry, event)
    local name = M.name(event)
    if not name then return end
    local item = registry[name] or {interval = 0}
    item.seq, item.ts, item.mono = event.seq, event.ts, event.mono
    item.state = event.status or 'ok'
    registry[name] = item
end

function M.write_registry(directory, registry)
    local path = directory .. '/topics.json'
    local file, err = io.open(path .. '.tmp', 'w')
    if not file then return nil, err end
    local written, write_err = file:write(json.encode(registry))
    local closed, close_err = file:close()
    if not written or not closed then return nil, write_err or close_err end
    return os.rename(path .. '.tmp', path)
end

-- Open active first so a rename during the read cannot hide its old contents.
-- Deduplicate by sequence because the two handles may refer to the same segment.
function M.scan(directory, decode)
    decode = decode or json.decode
    local active = io.open(directory .. '/events-core.jsonl', 'r')
    local archive = io.open(directory .. '/events-core.jsonl.1', 'r')
    local events, seen = {}, {}
    local function read(file)
        if not file then return end
        for line in file:lines() do
            local ok, event = pcall(decode, line)
            if ok and type(event) == 'table' and type(event.seq) == 'number'
                and event.seq >= 1 and event.seq == math.floor(event.seq) and not seen[event.seq] then
                events[#events + 1], seen[event.seq] = event, true
            end
        end
        file:close()
    end
    read(archive)
    read(active)
    table.sort(events, function(a, b) return a.seq < b.seq end)
    return events
end

function M.follow(cursor, events, topic)
    local messages, gaps, after_gap = {}, 0, 0
    local reset = #events > 0 and events[#events].seq < cursor
    if reset then cursor = 0 end
    for _, event in ipairs(events) do
        if event.seq > cursor then
            local missing = math.max(0, event.seq - cursor - 1)
            gaps = gaps + missing
            if missing > 0 then after_gap = event.seq end
            cursor = event.seq
            if (event.topic or M.name(event)) == topic then messages[#messages + 1] = event end
        end
    end
    return cursor, messages, gaps, reset, after_gap
end

function M.stats()
    return {count = 0, sum = 0, intervals = 0}
end

function M.observe(stats, event)
    local mono = tonumber(event.mono)
    if not mono then return end
    if stats.last and mono < stats.last then
        stats.count, stats.sum, stats.intervals = 0, 0, 0
        stats.last, stats.min, stats.max = nil, nil, nil
    end
    stats.count = stats.count + 1
    if stats.last then
        local delta = mono - stats.last
        stats.intervals, stats.sum = stats.intervals + 1, stats.sum + delta
        stats.min = math.min(stats.min or delta, delta)
        stats.max = math.max(stats.max or delta, delta)
    end
    stats.last = mono
end

return M
