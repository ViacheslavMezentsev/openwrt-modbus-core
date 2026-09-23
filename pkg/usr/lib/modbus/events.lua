local json = require("json")
local topics = require('topics')

local M = {}

local runtime_dir = os.getenv("MODBUS_RUNTIME_DIR") or "/tmp/modbus"
local max_log_bytes = 65536
local sequence = nil
local registry = {}

function M.configure_topics(unit, poll_interval, heartbeat_interval)
    registry = topics.registry(unit, poll_interval, heartbeat_interval)
    return topics.write_registry(runtime_dir, registry)
end

local function core_fifo()
    return runtime_dir .. "/events-core.fifo"
end

local function event_log()
    return runtime_dir .. "/events-core.jsonl"
end

local function rotated_event_log()
    return event_log() .. ".1"
end

local function sequence_file()
    return runtime_dir .. "/event-seq"
end

local function file_size(path)
    local file = io.open(path, "r")
    if not file then
        return 0
    end

    local size = file:seek("end") or 0
    file:close()
    return size
end

local function load_sequence()
    if sequence ~= nil then
        return sequence
    end

    local file = io.open(sequence_file(), "r")
    if not file then
        sequence = 0
        return sequence
    end

    sequence = tonumber(file:read("*a")) or 0
    file:close()
    return sequence
end

local function save_sequence(value)
    local temporary = sequence_file() .. ".tmp"
    local file = io.open(temporary, "w")
    if not file then
        return false, "event sequence unavailable"
    end

    file:write(tostring(value))
    file:write("\n")
    file:close()

    if not os.rename(temporary, sequence_file()) then
        return false, "event sequence update failed"
    end

    sequence = value
    return true
end

local function rotate_for(line_size)
    local current_size = file_size(event_log())
    if current_size + line_size <= max_log_bytes then
        return true
    end

    os.remove(rotated_event_log())
    if current_size > max_log_bytes then
        -- Discard a legacy oversized log rather than retaining it in RAM.
        os.remove(event_log())
        return true
    end

    if current_size > 0 and not os.rename(event_log(), rotated_event_log()) then
        return false, "event log rotation failed"
    end

    return true
end

function M.set_runtime_dir(path)
    runtime_dir = path or runtime_dir
    sequence = nil
end

function M.set_max_log_bytes(value)
    max_log_bytes = math.max(1024, tonumber(value) or max_log_bytes)
end

function M.ensure_runtime()
    os.execute(string.format("mkdir -p '%s'", runtime_dir))
    os.execute(string.format("[ -p '%s' ] || mkfifo '%s'", core_fifo(), core_fifo()))
end

function M.record(event)
    local next_sequence = load_sequence() + 1
    local payload = {}
    for key, value in pairs(event or {}) do
        payload[key] = value
    end
    payload.seq = next_sequence
    payload.topic = topics.name(payload)
    payload.mono = topics.clock()

    local line = json.encode(payload) .. "\n"
    local rotated, rotate_err = rotate_for(#line)
    if not rotated then
        return false, rotate_err
    end

    local file = io.open(event_log(), "a")
    if not file then
        return false, "event log unavailable"
    end

    local written, write_err = file:write(line)
    local closed, close_err = file:close()
    if not written or not closed then return false, write_err or close_err end

    local saved, save_err = save_sequence(next_sequence)
    if not saved then
        return false, save_err
    end

    topics.note(registry, payload)
    local registered, registry_err = topics.write_registry(runtime_dir, registry)
    if not registered then return false, registry_err end
    return true, next_sequence
end

function M.core_fifo_path()
    return core_fifo()
end

function M.event_log_path()
    return event_log()
end

function M.rotated_event_log_path()
    return rotated_event_log()
end

return M
