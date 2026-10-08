package.path = 'pkg/usr/lib/modbus/?.lua;' .. package.path
local topics = require('topics')
local registry = topics.registry(1, 5, 15)
assert(registry['/core/heartbeat'].interval == 15)
assert(registry['/devices/1/status'].interval == 0)
assert(not topics.registry(nil, 5, 15)['/devices/1/sample'])
assert(topics.name({kind='device_sample', unit=2}) == '/devices/2/sample')
assert(not topics.name({kind='unrelated'}))
topics.note(registry, {kind='device_status', unit=1, seq=2, mono=10, status='online'})
assert(registry['/devices/1/status'].state == 'online')
local stream = {
    {seq=8, kind='daemon_heartbeat', mono=8},
    {seq=9, kind='device_sample', unit=1, mono=9},
    {seq=10, kind='device_sample', unit=2, mono=10},
    {seq=11, kind='device_sample', unit=1, mono=14}
}
local cursor, messages, gaps = topics.follow(8, stream, '/devices/1/sample')
assert(cursor == 11 and #messages == 2 and gaps == 0)
local _, repeated = topics.follow(cursor, stream, '/devices/1/sample')
assert(#repeated == 0, 'cursor replayed messages')
local _, retained, lost, reset, after_gap = topics.follow(4, stream, '/devices/1/sample')
assert(lost == 3 and #retained == 2 and not reset and after_gap == 8)
local _, _, _, restarted = topics.follow(20, stream, '/devices/1/sample')
assert(restarted, 'sequence rollback not detected')
local stats = topics.stats()
topics.observe(stats, {mono=10, ts=99999})
topics.observe(stats, {mono=15, ts=1})
topics.observe(stats, {mono=20, ts=50000})
assert(stats.intervals == 2 and stats.sum == 10 and stats.intervals / stats.sum == 0.2)
topics.observe(stats, {mono=1})
assert(stats.count == 1 and stats.intervals == 0, 'monotonic rollback not reset')

-- Exercise actual segment reads without depending on a host JSON library.
local directory = assert(arg[1], 'test runtime directory required')
local function write(name, text)
    local f = assert(io.open(directory .. '/' .. name, 'w'))
    assert(f:write(text)); assert(f:close())
end
local function decode(line)
    local seq = tonumber(line)
    if not seq then error('malformed JSON fixture') end
    return {seq=seq, kind='device_sample', unit=1}
end
write('events-core.jsonl.1', '1\n2\n3\n')
write('events-core.jsonl', '3\n4\nbad\n5\n')
local data = topics.scan(directory, decode)
assert(#data == 5 and data[5].seq == 5, 'segments not deduplicated')
local position, batch = topics.follow(2, data, '/devices/1/sample')
assert(position == 5 and #batch == 3)
write('events-core.jsonl.1', '4\n5\n')
write('events-core.jsonl', '6\n7\n')
local _, next_batch, next_gaps = topics.follow(position, topics.scan(directory, decode), '/devices/1/sample')
assert(#next_batch == 2 and next_gaps == 0, 'rotation lost events')
write('events-core.jsonl.1', '12\n13\n')
write('events-core.jsonl', '14\n')
local _, _, dropped = topics.follow(7, topics.scan(directory, decode), '/devices/1/sample')
assert(dropped == 4, 'lost retained events not reported')
os.remove(directory .. '/events-core.jsonl')
os.remove(directory .. '/events-core.jsonl.1')
print('[test_topics] OK')
