#!/bin/sh
set -eu
timeout 65s ssh -T -o BatchMode=yes -o ConnectTimeout=8 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2 "${ROUTER_HOST:-openwrt}" sh -s <<'REMOTE'
set -eu
test_dir=$(mktemp -d /tmp/modbus-cli-test.XXXXXX)
cleanup() { rm -rf "$test_dir"; }
trap cleanup EXIT
modbus topics
if modbus echo /unknown --duration 1 2> "$test_dir/error"; then exit 1; fi
grep -q 'unknown topic' "$test_dir/error"
modbus echo /devices/1/sample --count 2 --duration 20 > "$test_dir/live"
lua - "$test_dir/live" <<'LUA'
local f = assert(io.open(arg[1]))
local count, last = 0, 0
for line in f:lines() do
    local event = assert(require('luci.jsonc').parse(line))
    assert(event.topic == '/devices/1/sample' and event.seq > last)
    assert(event.values.di and event.values.ai and event.values['do'] and event.values.ao)
    count, last = count + 1, event.seq
end
f:close()
assert(count == 2, 'echo did not deliver two samples')
print('live echo count/JSON: OK')
LUA
modbus hz /devices/1/sample --duration 12 > "$test_dir/hz"
grep -E 'hz=[0-9]+\.[0-9]+' "$test_dir/hz"
modbus echo /devices/1/status --duration 1 > /dev/null

mkdir "$test_dir/fixture"
lua - "$test_dir/fixture" <<'LUA'
package.path = '/usr/lib/modbus/?.lua;' .. package.path
local e = require('events')
e.set_runtime_dir(arg[1]); e.ensure_runtime(); e.configure_topics(nil, 1, 1)
assert(e.record({kind='daemon_heartbeat', ts=os.time()}))
LUA
MODBUS_RUNTIME_DIR="$test_dir/fixture" modbus echo /core/heartbeat --count 4 --duration 8 > "$test_dir/rotated" &
reader=$!
sleep 1
lua - "$test_dir/fixture" <<'LUA'
package.path = '/usr/lib/modbus/?.lua;' .. package.path
local e = require('events')
e.set_runtime_dir(arg[1]); e.set_max_log_bytes(1024)
for i=1,4 do assert(e.record({kind='daemon_heartbeat', ts=os.time(), payload=string.rep('x', 220)})) end
LUA
wait "$reader"
test -f "$test_dir/fixture/events-core.jsonl.1"
test "$(wc -l < "$test_dir/rotated")" -eq 4
echo 'CLI across rotation: OK'
REMOTE
