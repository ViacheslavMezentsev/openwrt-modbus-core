local json = require("json")

local M = {}

local runtime_dir = os.getenv("MODBUS_RUNTIME_DIR") or "/tmp/modbus"

local function core_fifo()
    return runtime_dir .. "/events-core.fifo"
end

local function event_log()
    return runtime_dir .. "/events-core.jsonl"
end

function M.set_runtime_dir(path)
    runtime_dir = path or runtime_dir
end

function M.ensure_runtime()
    os.execute(string.format("mkdir -p '%s'", runtime_dir))
    os.execute(string.format("[ -p '%s' ] || mkfifo '%s'", core_fifo(), core_fifo()))
end

function M.record(event)
    local file = io.open(event_log(), "a")
    if not file then
        return false, "event log unavailable"
    end

    file:write(json.encode(event))
    file:write("\n")
    file:close()

    return true
end

function M.core_fifo_path()
    return core_fifo()
end

function M.event_log_path()
    return event_log()
end

return M
