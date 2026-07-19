local json = require("json")

local M = {}

local runtime_dir = os.getenv("MODBUS_RUNTIME_DIR") or "/tmp/modbus"
local cache_file = nil
local state = {
    devices = {},
    meta = {}
}

local function ensure_cache_file()
    cache_file = runtime_dir .. "/cache.json"
end

local function ensure_device_bucket(device, regtype)
    local device_key = tostring(device)
    local type_key = tostring(regtype)

    state.devices[device_key] = state.devices[device_key] or {}
    state.devices[device_key][type_key] = state.devices[device_key][type_key] or {}

    return state.devices[device_key][type_key]
end

function M.set_runtime_dir(path)
    runtime_dir = path or runtime_dir
    ensure_cache_file()
end

function M.ensure_runtime()
    ensure_cache_file()
    os.execute(string.format("mkdir -p '%s'", runtime_dir))
end

function M.load()
    ensure_cache_file()
    local file = io.open(cache_file, "r")
    if not file then
        return false
    end

    local content = file:read("*a")
    file:close()

    if content == nil or content == "" then
        return false
    end

    local decoded = json.decode(content)
    if type(decoded) == "table" then
        state = decoded
        state.devices = state.devices or {}
        state.meta = state.meta or {}
        return true
    end

    return false
end

function M.set(device, regtype, address, value)
    local bucket = ensure_device_bucket(device, regtype)
    bucket[tostring(address)] = value
end

function M.get(device, regtype, address)
    local bucket = state.devices[tostring(device)]
    if not bucket or not bucket[tostring(regtype)] then
        return nil
    end
    return bucket[tostring(regtype)][tostring(address)]
end

function M.mark(key, value)
    state.meta[tostring(key)] = value
end

function M.meta(key)
    return state.meta[tostring(key)]
end

function M.snapshot()
    return state
end

function M.flush()
    ensure_cache_file()
    local tmp_file = cache_file .. ".tmp"
    local file = io.open(tmp_file, "w")
    if not file then
        return false, "unable to open temp file"
    end

    file:write(json.encode(state))
    file:close()

    local ok = os.rename(tmp_file, cache_file)
    if not ok then
        os.remove(tmp_file)
        return false, "atomic rename failed"
    end

    return true
end

function M.reset()
    state = {
        devices = {},
        meta = {}
    }
end

return M
