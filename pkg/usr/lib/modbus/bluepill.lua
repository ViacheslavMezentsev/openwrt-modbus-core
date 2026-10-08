local serial = require('serial_rtu')
local M = {}

function M.poll(config, connection)
    local port, err = connection
    if not port then port, err = serial.open(config.device, config.baudrate, config.parity, config.request_timeout_ms) end
    if not port then return nil, err end
    local result = {}
    for _, item in ipairs({{'di', 2, 2}, {'ai', 4, 5}, {'do', 1, 2}, {'ao', 3, 1}}) do
        local values, read_err = port:read(config.unit_id, item[2], 0, item[3])
        if not values then
            if not connection then port:close() end
            return nil, item[1] .. ': ' .. read_err
        end
        result[item[1]] = values
    end
    if not connection then port:close() end
    return result
end

return M
