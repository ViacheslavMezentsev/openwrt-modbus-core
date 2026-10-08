package.path = 'pkg/usr/lib/modbus/?.lua;' .. package.path
local events = require('events')
local topics = require('topics')
local json = require('json')
local root = assert(arg[1], 'temporary directory required')
local original_clock = topics.clock
topics.clock = function() return 123.25 end
local limit = 1024
local files = {'events-core.jsonl', 'events-core.jsonl.1', 'event-seq', 'topics.json'}
local function read(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local text = f:read('*a'); f:close()
    return text
end
local function snapshot(dir)
    local result = {}
    for _, name in ipairs(files) do result[name] = read(dir .. '/' .. name) end
    return result
end
local function unchanged(dir, previous)
    for _, name in ipairs(files) do
        assert(read(dir .. '/' .. name) == previous[name], 'changed on rejection: ' .. name)
    end
end
local function event_with_size(bytes, seq)
    local full = {kind='daemon_heartbeat', topic='/core/heartbeat', mono=123.25,
        seq=seq, payload=''}
    local overhead = #json.encode(full) + 1
    assert(bytes >= overhead)
    local event = {kind=full.kind, payload=string.rep('x', bytes-overhead)}
    return event
end
local function reject(dir, event)
    local previous = snapshot(dir)
    local ok, err = events.record(event)
    assert(not ok and err == 'event exceeds log size limit')
    unchanged(dir, previous)
end

-- TC-24/32: byte boundaries include JSON escaping, metadata and trailing LF.
local dir = root .. '/journal-boundaries'
events.set_runtime_dir(dir)
events.ensure_runtime()
events.set_max_log_bytes(limit)
assert(events.configure_topics(nil, 1, 1))
reject(dir, event_with_size(limit+1, 1))
assert(not read(dir .. '/events-core.jsonl') and not read(dir .. '/event-seq'))
local ok, seq = events.record(event_with_size(limit-1, 1))
assert(ok and seq == 1 and #assert(read(dir .. '/events-core.jsonl')) == limit-1)
local first = read(dir .. '/events-core.jsonl')
ok, seq = events.record(event_with_size(limit, 2))
assert(ok and seq == 2 and #assert(read(dir .. '/events-core.jsonl')) == limit)
assert(read(dir .. '/events-core.jsonl.1') == first)
reject(dir, event_with_size(limit+1, 3))
reject(dir, {kind='daemon_heartbeat', payload=string.rep('\n', 600)})
for expected=3,15 do
    local previous_active = read(dir .. '/events-core.jsonl')
    ok, seq = events.record(event_with_size(limit, expected))
    assert(ok and seq == expected, 'rejection consumed a sequence number')
    assert(#assert(read(dir .. '/events-core.jsonl')) == limit)
    assert(read(dir .. '/events-core.jsonl.1') == previous_active)
    assert(not read(dir .. '/events-core.jsonl.2'))
end

-- Exact cumulative boundary must not rotate until the next accepted byte.
dir = root .. '/journal-cumulative'
events.set_runtime_dir(dir)
events.ensure_runtime()
assert(events.configure_topics(nil, 1, 1))
assert(events.record(event_with_size(512, 1)))
assert(events.record(event_with_size(512, 2)))
assert(#assert(read(dir .. '/events-core.jsonl')) == limit)
assert(not read(dir .. '/events-core.jsonl.1'))
reject(dir, event_with_size(limit+1, 3))
ok, seq = events.record(event_with_size(100, 3))
assert(ok and seq == 3)
assert(#assert(read(dir .. '/events-core.jsonl.1')) == limit)
assert(#assert(read(dir .. '/events-core.jsonl')) == 100)
topics.clock = original_clock
print('[test_events] OK: exact byte limits, rotation, oversized rejection preserves files/seq')
