-- Run with the core stopped and LUA_PATH pointing to the tested modules.
local serial = require('serial_rtu')
local port = assert(serial.open('/dev/ttyACM0', 115200, 'N', 1000))
local original
local ok, err = xpcall(function()
    local sys = assert(port:read(1, 4, 256, 8))
    assert(sys[1] == 0x5741 and sys[2] == 2 and sys[3] == 3, 'unexpected firmware')
    print('system: signature=' .. sys[1] .. ' version=' .. sys[2]
        .. ' pressed=' .. sys[4] .. ' count=' .. (sys[5]*65536+sys[6]))
    local coil = assert(port:read(1, 1, 256, 1))
    original = coil[1] == 1
    for _, value in ipairs({true, true, false, false}) do
        assert(port:write_coil(1, 256, value))
        require('nixio').nanosleep(0, 100000000)
        local readback = assert(port:read(1, 1, 256, 1))
        assert(readback[1] == (value and 1 or 0), 'LED readback mismatch')
    end
    local missing, exception = port:write_coil(1, 257, true)
    assert(not missing and exception == 'Modbus exception 2', tostring(exception))
    assert(port:read(1, 2, 256, 1))
    assert(port:read(1, 2, 0, 2))
    assert(port:read(1, 4, 0, 5))
    assert(port:read(1, 1, 0, 2))
    assert(port:read(1, 3, 0, 1))
end, debug.traceback)
local restored, restore_err = true, nil
if original ~= nil then restored, restore_err = port:write_coil(1, 256, original) end
port:close()
assert(restored, 'LED restore failed: ' .. tostring(restore_err))
assert(ok, err)
print('[test_system_board] OK: LED set/readback, duplicate writes, invalid address, legacy reads')
