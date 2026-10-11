package.path = './pkg/usr/lib/modbus/?.lua;' .. package.path
local registry = require('event_registry')
local total = 0
local function check(name, fn)
    fn()
    total = total + 1
    print('[registry] OK ' .. name)
end
local function fail(code, value, err)
    assert(value == nil and err == code, tostring(err) .. ' ~= ' .. code)
end
local function new()
    return assert(registry.new({sessions=2, definitions=2, subscriptions=3}))
end
local function spec(owner)
    return {definitions={{topic='/packages/' .. owner .. '/bell', schema_version=1}},
        subscriptions={{id='play', topic='/packages/bell/bell'},
            {id='audit', topic='/packages/bell/bell'}}}
end
local topic = '/packages/bell/bell'

-- Core TC-61 (registry subset): logical owner/session lifecycle, not handshake.
check('explicit limits and defensive policy copy', function()
    fail('invalid_limits', registry.new({}))
    fail('invalid_limits', registry.new({sessions=0, definitions=1, subscriptions=1}))
    fail('invalid_limits', registry.new({sessions=math.huge, definitions=1, subscriptions=1}))
    local policy = {sessions=1, definitions=2, subscriptions=3}
    local r = assert(registry.new(policy)); policy.sessions = 20
    assert(r:open('one')); fail('session_limit', r:open('two'))
end)
check('owner exclusivity and forged session', function()
    local r = new(); local a = assert(r:open('bell'))
    fail('owner_busy', r:open('bell')); fail('invalid_owner', r:open('../bell'))
    fail('unknown_session', r:status({})); assert(r:status(a).generation == 0)
end)
check('closed handles cannot alter reconnected owner', function()
    local r = new(); local a, old = r:open('bell')
    assert(r:replace(a, 0, 'v1', spec('bell'))); assert(r:close(a))
    assert(#r:snapshot(topic) == 0)
    local b, fresh = r:open('bell'); assert(old.session_id ~= fresh.session_id)
    fail('unknown_session', r:replace(a, 0, 'v2', spec('bell')))
    fail('unknown_session', r:close(a)); assert(r:status(b).generation == 0)
end)
-- Core TC-62/43: whole-set validation and idempotency.
check('atomic rejection preserves entire old set', function()
    local r = new(); local a = assert(r:open('bell'))
    assert(r:replace(a, 0, 'v1', spec('bell')))
    local bad = spec('bell'); bad.subscriptions[2].topic = '*'
    fail('invalid_subscription', r:replace(a, 1, 'v2', bad))
    assert(r:can_publish(a, topic, 1)); assert(#r:snapshot(topic) == 2)
    assert(r:status(a).generation == 1 and r:status(a).revision == 'v1')
end)
check('same revision normalizes list order and lost reply', function()
    local r = new(); local a = assert(r:open('bell')); local s = spec('bell')
    s.definitions[2] = {topic='/packages/bell/end', schema_version=2}
    assert(r:replace(a, 0, 'v1', s).generation == 1)
    s.subscriptions[1], s.subscriptions[2] = s.subscriptions[2], s.subscriptions[1]
    s.definitions[1], s.definitions[2] = s.definitions[2], s.definitions[1]
    assert(r:replace(a, 0, 'v1', s).generation == 1)
    s.definitions[1].schema_version = 3
    fail('revision_conflict', r:replace(a, 1, 'v1', s))
    fail('stale_generation', r:replace(a, 0, 'v2', spec('bell')))
end)
check('unregister retains generation tombstone', function()
    local r = new(); local a = assert(r:open('bell'))
    assert(r:replace(a, 0, 'v1', spec('bell')))
    assert(r:unregister(a, 1).generation == 2)
    assert(r:unregister(a, 1).generation == 2) -- lost response retry
    assert(r:unregister(a, 2).generation == 2)
    fail('stale_generation', r:unregister(a, 3))
    fail('undeclared_event_type', r:can_publish(a, topic, 1))
    assert(r:replace(a, 2, 'v2', spec('bell')).generation == 3)
    fail('stale_generation', r:unregister(a, 1)); assert(#r:snapshot(topic) == 2)
end)
check('inputs and returned status do not alias private state', function()
    local r = new(); local a = assert(r:open('bell')); local s = spec('bell')
    local status = assert(r:replace(a, 0, 'v1', s))
    s.subscriptions[1].topic = '/other'; s.definitions[1].schema_version = 5
    status.generation = 200; status.owner = 'other'; a.generation = 400
    assert(r:status(a).generation == 1); assert(r:can_publish(a, topic, 1))
    assert(#r:snapshot(topic) == 2)
end)
-- Core TC-63/47 (registry subset): recipients, not socket delivery.
check('one topic fans out to two owners and three subscriptions', function()
    local r = new(); local a = assert(r:open('bell')); local b = assert(r:open('observer'))
    assert(r:replace(b, 0, 'v1', {definitions={}, subscriptions={{id='log', topic=topic}}}))
    assert(#r:snapshot(topic) == 1) -- Subscription can precede definition.
    assert(r:replace(a, 0, 'v1', spec('bell')))
    local shot = r:snapshot(topic)
    assert(#shot == 3 and shot[1].subscription_id == 'audit'
        and shot[2].subscription_id == 'play' and shot[3].owner == 'observer')
    fail('undeclared_event_type', r:can_publish(b, topic, 1))
end)
check('dispatch snapshot survives replacement and disconnect', function()
    local r = new(); local a = assert(r:open('bell'))
    assert(r:replace(a, 0, 'v1', spec('bell')))
    local old = r:snapshot(topic)
    assert(r:replace(a, 1, 'v2', {definitions={}, subscriptions={}}))
    assert(#old == 2 and old[1].registration_generation == 1)
    assert(#r:snapshot(topic) == 0); assert(r:close(a)); assert(#old == 2)
end)
check('snapshot mutation cannot corrupt later dispatch', function()
    local r = new(); local a = assert(r:open('bell'))
    assert(r:replace(a, 0, 'v1', spec('bell')))
    local shot = r:snapshot(topic); shot[1].owner='fake'; shot[2]=nil
    local later = r:snapshot(topic); assert(#later == 2 and later[1].owner == 'bell')
end)
check('definitions cannot impersonate core or another package', function()
    local r = new(); local a = assert(r:open('bell'))
    for _, name in ipairs({'/core/status', '/devices/1/sample', '/packages/bell2/bell'}) do
        local s = spec('bell'); s.definitions[1].topic = name
        fail('invalid_definition', r:replace(a, 0, 'v1', s))
    end
    assert(r:status(a).generation == 0)
end)
check('publication requires matching declared schema', function()
    local r = new(); local a = assert(r:open('bell'))
    assert(r:replace(a, 0, 'v1', spec('bell')))
    assert(r:can_publish(a, topic, 1))
    fail('undeclared_event_type', r:can_publish(a, topic, 2))
    fail('invalid_event_type', r:can_publish(a, topic, 0/0))
end)
check('duplicates are rejected without replacing old state', function()
    local r = new(); local a = assert(r:open('bell')); local s = spec('bell')
    s.definitions[2] = s.definitions[1]
    fail('invalid_definition', r:replace(a, 0, 'v1', s))
    s = spec('bell'); s.subscriptions[2].id = s.subscriptions[1].id
    fail('invalid_subscription', r:replace(a, 0, 'v1', s))
    assert(r:status(a).generation == 0)
end)
check('sparse and excessive arrays do not partially commit', function()
    local r = new(); local a = assert(r:open('bell'))
    for _, list in ipairs({{[2]={}}, {[1]={}, extra={}}, {[1.5]={}}, {[1000000]={}}, {{},{},{},{}}}) do
        fail('invalid_or_excessive_list', r:replace(a, 0, 'v1', {definitions={}, subscriptions=list}))
    end
    assert(r:status(a).generation == 0)
end)
check('unknown fields and metatables never execute', function()
    local r = new(); local a = assert(r:open('bell'))
    local s = spec('bell'); s.extra = true
    fail('invalid_registration', r:replace(a, 0, 'v1', s))
    s = spec('bell'); setmetatable(s, {__index=function() error('must not run') end})
    fail('invalid_registration', r:replace(a, 0, 'v1', s))
    s = spec('bell'); s.definitions[1].extra = true
    fail('invalid_definition', r:replace(a, 0, 'v1', s))
end)
check('topic syntax and identifier bounds', function()
    local r = new(); local a = assert(r:open('bell'))
    for _, name in ipairs({'relative','/a//b','/a/','/a/../b','/a/*','/'..string.rep('x',65)}) do
        fail('invalid_topic', r:snapshot(name))
    end
    fail('invalid_revision', r:replace(a, -1, 'v1', spec('bell')))
    fail('invalid_revision', r:replace(a, 0, string.rep('x',65), spec('bell')))
    fail('invalid_generation', r:unregister(a, math.huge))
end)
check('exact subscription quota accepted, next rejected', function()
    local r = new(); local a = assert(r:open('bell')); local s = spec('bell')
    s.subscriptions[3]={id='third', topic=topic}
    assert(r:replace(a, 0, 'v1', s)); assert(#r:snapshot(topic)==3)
    s.subscriptions[4]={id='fourth', topic=topic}
    fail('invalid_or_excessive_list', r:replace(a, 1, 'v2', s))
    assert(#r:snapshot(topic)==3 and r:status(a).generation==1)
end)
print('[test_event_registry] OK: ' .. total .. ' cases; pure registry only')