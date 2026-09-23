#!/bin/sh
set -eu
# Run after enabling the bluepill profile; no serial access outside the daemon.
timeout 60s ssh -T -o BatchMode=yes -o ConnectTimeout=8 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2 "${ROUTER_HOST:-openwrt}" lua - <<'LUA'
local json = require('luci.jsonc')
local function status(name)
    local pipe = assert(io.popen('wget -T 2 -qO- http://127.0.0.1/cgi-bin/modbus-' .. name .. '-status'))
    local value = json.parse(pipe:read('*a'))
    pipe:close()
    return value
end
for _ = 1, 15 do
    local core, demo = status('core'), status('demo')
    if core and demo and core.meta.data_valid and core.meta.transport_status == 'online'
        and os.time() - core.meta.last_success <= 10 and demo.last_event
        and demo.last_event.kind == 'device_sample' and demo.last_event.ts == core.meta.last_success then
        local sample = demo.last_event
        local device = assert(core.devices[tostring(sample.unit)])
        for kind, registers in pairs(sample.values) do
            for i, value in ipairs(registers) do
                assert(device[kind][tostring(i - 1)] == value, 'cache/demo mismatch')
            end
        end
        print('[bluepill-router] cache and demo match: ' .. json.stringify(sample))
        return
    end
    os.execute('sleep 1')
end
error('No matching fresh BluePill sample in core and demo CGI')
LUA
