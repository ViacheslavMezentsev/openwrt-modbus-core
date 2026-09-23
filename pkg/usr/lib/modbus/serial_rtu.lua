local nixio = require('nixio')
local rtu = require('rtu')
local M = {}

local function now()
    -- Kernel uptime is monotonic even if NTP adjusts wall-clock time.
    local f = assert(io.open('/proc/uptime', 'r'))
    local value = assert(tonumber(f:read('*l'):match('^[%d.]+')))
    f:close()
    return value
end

local function ready(fd, flag, deadline)
    local remaining = deadline - now()
    if remaining <= 0 then return nil, 'serial timeout' end
    local items = {{fd = fd, events = nixio.poll_flags(flag)}}
    local result = nixio.poll(items, math.ceil(remaining * 1000))
    if not result or result == 0 then return nil, 'serial timeout' end
    return true
end

function M.open(device, baudrate, parity, timeout_ms)
    if not device:match('^/dev/ttyACM%d+$') or tostring(baudrate) ~= '115200' or parity ~= 'N' then
        return nil, 'BluePill profile requires /dev/ttyACM<number>, 115200 8N1'
    end
    local pipe = io.popen('stty -F ' .. device .. ' -g 2>/dev/null')
    if not pipe then return nil, 'stty unavailable' end
    local saved = pipe:read('*a'):gsub('%s+$', '')
    pipe:close()
    if saved == '' or not saved:match('^[%x:]+$') then return nil, 'serial device unavailable' end
    local fd, err = nixio.open(device, 'r+')
    if not fd then return nil, tostring(err) end
    if os.execute('stty -F ' .. device .. ' 115200 cs8 -cstopb -parenb raw -echo -ixon -ixoff -crtscts clocal min 0 time 0') ~= 0 then
        fd:close()
        return nil, 'serial configuration failed'
    end
    fd:setblocking(false)
    local port = {}
    function port:close()
        os.execute('stty -F ' .. device .. ' ' .. saved .. ' 2>/dev/null')
        fd:close()
    end
    function port:read(unit, fn, address, count)
        local request, request_err = rtu.request(unit, fn, address, count)
        if not request then return nil, request_err end
        -- Bounded drain: stale replies must not be mistaken for this request.
        for _ = 1, 8 do
            local stale = fd:read(256)
            if not stale or #stale == 0 then break end
        end
        nixio.nanosleep(0, 5000000)
        local deadline = now() + timeout_ms / 1000
        local sent = 0
        while sent < #request do
            local ok, err = ready(fd, 'out', deadline)
            if not ok then return nil, err end
            local n = fd:write(request:sub(sent + 1))
            if not n or n == 0 then return nil, 'serial write failed' end
            sent = sent + n
        end
        local response = ''
        while true do
            local ok, err = ready(fd, 'in', deadline)
            if not ok then return nil, err end
            local chunk = fd:read(256 - #response)
            if not chunk or #chunk == 0 then return nil, 'serial read failed' end
            response = response .. chunk
            if #response >= 3 then
                local size = response:byte(2) >= 128 and 5 or response:byte(3) + 5
                if size > 256 then return nil, 'oversized response' end
                if #response >= size then return rtu.decode(response, unit, fn, count) end
            end
        end
    end
    return port
end

return M
