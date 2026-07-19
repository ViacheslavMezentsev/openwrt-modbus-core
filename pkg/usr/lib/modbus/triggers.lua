local M = {}

local config_dir = os.getenv("MODBUS_CONFIG_DIR") or "/etc/modbus-rtu-core"

function M.set_config_dir(path)
    config_dir = path or config_dir
end

function M.list()
    local command = string.format("find '%s/triggers.d' -maxdepth 1 -type f -name '*.json' 2>/dev/null | sort", config_dir)
    local pipe = io.popen(command)
    if not pipe then
        return {}
    end

    local files = {}
    for line in pipe:lines() do
        files[#files + 1] = line
    end
    pipe:close()

    return files
end

return M
