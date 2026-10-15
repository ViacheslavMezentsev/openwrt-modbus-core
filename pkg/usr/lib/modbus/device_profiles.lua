-- Core 6.9.1-3: isolated schema/activation; filesystem trust is adapter-owned.
local json = require("modbus.json_strict")
local M = {}
local snapshots=setmetatable({}, {__mode="k"})
function M.is_snapshot(value) return snapshots[value]==true end
local BYTES, RANGES, PROFILES, TOTAL, DEVICES = 16384, 64, 16, 256, 32
local function fail(code) error({code=code}, 0) end
local function identifier(id)
    return type(id) == "string" and #id >= 1 and #id <= 32
        and id:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
end
local function copy(t)
    local result = {}
    for k,v in pairs(t) do result[k] = v end
    return result
end
local function readonly(methods)
    return setmetatable({}, {__index=methods, __newindex=function() error("read-only view", 2) end,
                             __metatable="profile view"})
end
local function fields(value, allowed)
    if json.kind(value) ~= "object" then fail("object") end
    for key in pairs(value) do if not allowed[key] then fail("field") end end
end
local function integer(t, key, low, high, default)
    local value = t[key]
    if value == nil and default ~= nil then return default end
    if type(value) ~= "number" or json.number_kind(t, key) ~= "integer"
        or value < low or value > high then fail("integer_" .. key) end
    return value
end
local function boolean(t, key)
    local value = t[key]
    if value == nil then return false end
    if type(value) ~= "boolean" then fail("boolean_" .. key) end
    return value
end
local range_fields = {["function"]=true, start=true, count=true, safe_read=true,
                      mergeable=true, max_count=true, max_gap=true}
local function decode(text, expected_id)
    if not identifier(expected_id) then fail("profile_id") end
    local doc, err = json.decode(text, {bytes=BYTES, depth=3})
    if err then error({code="json_" .. err.code, offset=err.offset}, 0) end
    fields(doc, {id=true, read_ranges=true})
    if not identifier(doc.id) or doc.id ~= expected_id then fail("profile_id") end
    local input = doc.read_ranges
    if json.kind(input) ~= "array" or #input < 1 or #input > RANGES then fail("ranges") end
    local ranges = {}
    for i,t in ipairs(input) do
        fields(t, range_fields)
        local fn = integer(t, "function", 1, 4)
        local start = integer(t, "start", 0, 65535)
        local count = integer(t, "count", 1, 65536-start)
        local item = {["function"]=fn, start=start, count=count,
            max_count=integer(t, "max_count", 1, fn <= 2 and 2000 or 125, 1),
            max_gap=integer(t, "max_gap", 0, count-1, 0),
            safe_read=boolean(t, "safe_read"), mergeable=boolean(t, "mergeable")}
        if item.mergeable and not item.safe_read then fail("unsafe_merge") end
        ranges[i] = item
    end
    table.sort(ranges, function(a,b)
        if a["function"] ~= b["function"] then return a["function"] < b["function"] end
        return a.start < b.start
    end)
    for i=2,#ranges do
        local a,b = ranges[i-1], ranges[i]
        if a["function"] == b["function"] and a.start+a.count > b.start then fail("overlap") end
    end
    return readonly({
        id=function() return expected_id end,
        count=function() return #ranges end,
        range=function(_, index)
            if type(index) ~= "number" or index ~= math.floor(index) or not ranges[index] then
                return nil, {code="range_index"}
            end
            return copy(ranges[index])
        end
    }), #ranges
end
function M.decode(text, expected_id)
    local ok, value = pcall(decode, text, expected_id)
    if not ok then return nil, value end
    return value
end
local function view(bindings, profiles, profile_count, range_count)
    local result=readonly({
        profile=function(_, device) return profiles[bindings[device]] end,
        binding=function(_, device) return bindings[device] end,
        devices=function()
            local result = {}
            for device in pairs(bindings) do result[#result+1] = device end
            table.sort(result); return result
        end,
        profile_count=function() return profile_count end,
        range_count=function() return range_count end
    })
    snapshots[result]=true
    return result
end
function M.new(read_profile)
    -- Trusted synchronous callback(id, maximum_bytes). No default io.open fallback.
    if type(read_profile) ~= "function" then return nil, {code="reader_required"} end
    local current = view({}, {}, 0, 0)
    local busy = false
    local function activate(bindings, maintenance, active_operations)
        if maintenance ~= true or type(active_operations) ~= "number" or active_operations ~= 0 then
            fail("maintenance")
        end
        if type(bindings) ~= "table" or getmetatable(bindings) ~= nil then fail("bindings") end
        local selected, ids, ordered, device_count = {}, {}, {}, 0
        for device, id in pairs(bindings) do
            if not identifier(device) or not identifier(id) then fail("binding_id") end
            device_count = device_count + 1
            if device_count > DEVICES then fail("device_limit") end
            selected[device] = id
            if not ids[id] then
                ids[id] = true; ordered[#ordered+1] = id
                if #ordered > PROFILES then fail("profile_limit") end
            end
        end
        table.sort(ordered)
        local profiles, total = {}, 0
        for _,id in ipairs(ordered) do
            local ok, data = pcall(read_profile, id, BYTES+1)
            if not ok or type(data) ~= "string" then fail("read") end
            local profile, count = decode(data, id)
            total = total + count
            if total > TOTAL then fail("total_ranges") end
            profiles[id] = profile
        end
        return view(selected, profiles, #ordered, total)
    end
    return readonly({
        current=function() return current end,
        activate=function(_, bindings, maintenance, active_operations)
            if busy then return nil, {code="busy"} end
            busy = true
            local ok, candidate = pcall(activate, bindings, maintenance, active_operations)
            busy = false
            if not ok then return nil, candidate end
            current = candidate -- The only publication point; previous views stay valid.
            return current
        end
    })
end
return M
