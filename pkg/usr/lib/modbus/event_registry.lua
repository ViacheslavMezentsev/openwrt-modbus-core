-- Internal registry for the future public API; no I/O, callbacks or audio.
-- Core specification 4.5.6, 4.5.18-4.5.21. Not wired into modbusd yet.
local M = {}
local MAX_INTEGER = 9007199254740991

local function integer(n, minimum)
    return type(n) == 'number' and n >= minimum and n <= MAX_INTEGER and n % 1 == 0
end

local function plain(t)
    return type(t) == 'table' and getmetatable(t) == nil
end

local function fields(t, allowed)
    if not plain(t) then return false end
    for key in pairs(t) do
        if not allowed[key] then return false end
    end
    return true
end

local function identifier(s)
    return type(s) == 'string' and #s >= 1 and #s <= 64
        and s:match('^[a-zA-Z0-9_-]+$') ~= nil
end

local function topic(s)
    if type(s) ~= 'string' or #s < 2 or #s > 256 or s:sub(1, 1) ~= '/'
        or s:sub(-1) == '/' or s:find('//', 1, true) then return false end
    for part in s:gmatch('[^/]+') do
        if not identifier(part) then return false end
    end
    return true
end

-- Reject holes, hash keys, excessive indices and metatables before copying.
local function array_size(t, limit)
    if not plain(t) then return nil end
    local count = 0
    for key in pairs(t) do
        count = count + 1
        if count > limit or not integer(key, 1) or key > limit then return nil end
    end
    for i = 1, count do
        if rawget(t, i) == nil then return nil end
    end
    return count
end

local function normalize(owner, spec, limits)
    if not fields(spec, {definitions=true, subscriptions=true}) then
        return nil, 'invalid_registration'
    end
    local nd = array_size(spec.definitions, limits.definitions)
    local ns = array_size(spec.subscriptions, limits.subscriptions)
    if not nd or not ns then return nil, 'invalid_or_excessive_list' end
    local result = {definitions={}, subscriptions={}}
    local seen = {}
    local prefix = '/packages/' .. owner .. '/'
    for i = 1, nd do
        local d = spec.definitions[i]
        if not fields(d, {topic=true, schema_version=true}) or not topic(d.topic)
            or d.topic:sub(1, #prefix) ~= prefix or not integer(d.schema_version, 1)
            or seen[d.topic] then return nil, 'invalid_definition' end
        seen[d.topic] = true
        result.definitions[i] = {topic=d.topic, schema_version=d.schema_version}
    end
    seen = {}
    for i = 1, ns do
        local sub = spec.subscriptions[i]
        if not fields(sub, {id=true, topic=true}) or not identifier(sub.id)
            or not topic(sub.topic) or seen[sub.id] then return nil, 'invalid_subscription' end
        seen[sub.id] = true
        result.subscriptions[i] = {id=sub.id, topic=sub.topic}
    end
    table.sort(result.definitions, function(a, b) return a.topic < b.topic end)
    table.sort(result.subscriptions, function(a, b) return a.id < b.id end)
    return result
end

local function same(a, b)
    if #a.definitions ~= #b.definitions or #a.subscriptions ~= #b.subscriptions then return false end
    for i, d in ipairs(a.definitions) do
        local other = b.definitions[i]
        if d.topic ~= other.topic or d.schema_version ~= other.schema_version then return false end
    end
    for i, sub in ipairs(a.subscriptions) do
        local other = b.subscriptions[i]
        if sub.id ~= other.id or sub.topic ~= other.topic then return false end
    end
    return true
end

function M.new(options)
    -- Mandatory policy injection: these are counts, not a measured RAM budget.
    if not fields(options, {sessions=true, definitions=true, subscriptions=true})
        or not integer(options.sessions, 1) or not integer(options.definitions, 1)
        or not integer(options.subscriptions, 1) then return nil, 'invalid_limits' end
    local limits = {sessions=options.sessions, definitions=options.definitions,
        subscriptions=options.subscriptions}
    local sessions, owners, count, next_id = {}, {}, 0, 0
    local api = {}
    local function current(handle)
        return sessions[handle]
    end
    local function state(record)
        return {owner=record.owner, session_id=record.session_id,
            generation=record.generation, revision=record.revision,
            definitions=#record.spec.definitions, subscriptions=#record.spec.subscriptions}
    end

    function api:open(owner)
        if not identifier(owner) then return nil, 'invalid_owner' end
        if owners[owner] then return nil, 'owner_busy' end
        if count >= limits.sessions then return nil, 'session_limit' end
        if next_id == MAX_INTEGER then return nil, 'session_id_exhausted' end
        next_id = next_id + 1
        local handle = {} -- Capability by identity, never populated with mutable state.
        local record = {owner=owner, session_id=string.format('%.0f', next_id), generation=0,
            spec={definitions={}, subscriptions={}}}
        sessions[handle], owners[owner], count = record, handle, count + 1
        return handle, state(record)
    end

    function api:status(handle)
        local record = current(handle)
        if not record then return nil, 'unknown_session' end
        return state(record)
    end

    function api:replace(handle, expected, revision, spec)
        local record = current(handle)
        if not record then return nil, 'unknown_session' end
        if not integer(expected, 0) or not identifier(revision) then return nil, 'invalid_revision' end
        local normalized, err = normalize(record.owner, spec, limits)
        if not normalized then return nil, err end
        -- An identical retry of the current revision succeeds even if its first
        -- reply was lost (expected still names the pre-replacement generation).
        if revision == record.revision then
            if same(normalized, record.spec) then return state(record) end
            return nil, 'revision_conflict'
        end
        if expected ~= record.generation then return nil, 'stale_generation' end
        if record.generation == MAX_INTEGER then return nil, 'generation_exhausted' end
        record.spec, record.revision = normalized, revision
        record.generation = record.generation + 1
        return state(record)
    end

    function api:unregister(handle, expected)
        local record = current(handle)
        if not record then return nil, 'unknown_session' end
        if not integer(expected, 0) then return nil, 'invalid_generation' end
        -- A lost unregister reply can be retried against the already empty set.
        -- Never let that old request remove a subsequently installed revision.
        if record.revision == nil and expected <= record.generation then return state(record) end
        if expected ~= record.generation then return nil, 'stale_generation' end
        if record.generation == MAX_INTEGER then return nil, 'generation_exhausted' end
        record.spec, record.revision = {definitions={}, subscriptions={}}, nil
        record.generation = record.generation + 1
        return state(record)
    end

    function api:close(handle)
        local record = current(handle)
        if not record then return nil, 'unknown_session' end
        owners[record.owner], sessions[handle], count = nil, nil, count - 1
        return true
    end

    function api:can_publish(handle, name, version)
        local record = current(handle)
        if not record then return nil, 'unknown_session' end
        if not topic(name) or not integer(version, 1) then return nil, 'invalid_event_type' end
        for _, d in ipairs(record.spec.definitions) do
            if d.topic == name and d.schema_version == version then return true end
        end
        return nil, 'undeclared_event_type'
    end

    function api:snapshot(name)
        if not topic(name) then return nil, 'invalid_topic' end
        local recipients = {}
        for _, record in pairs(sessions) do
            for _, sub in ipairs(record.spec.subscriptions) do
                if sub.topic == name then
                    recipients[#recipients+1] = {owner=record.owner, session_id=record.session_id,
                        subscription_id=sub.id, registration_generation=record.generation}
                end
            end
        end
        table.sort(recipients, function(a, b)
            if a.owner ~= b.owner then return a.owner < b.owner end
            return a.subscription_id < b.subscription_id
        end)
        return recipients -- Independent value snapshot; never a registry reference.
    end

    return api
end
return M