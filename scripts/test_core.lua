package.path = table.concat({
    "pkg/usr/lib/modbus/?.lua",
    package.path
}, ";")

os.setenv = os.setenv or function() end

local optimizer = require("optimizer")
local cache = require("cache")
local events = require("events")
local json = require("json")

local function assert_true(condition, message)
    if not condition then
        error(message)
    end
end

local runtime_dir = "/tmp/openwrt-modbus-core-tests"
cache.set_runtime_dir(runtime_dir)
cache.ensure_runtime()
cache.reset()
events.set_runtime_dir(runtime_dir)
events.ensure_runtime()

local groups = optimizer.group_registers({1, 2, 3, 8, 9, 20}, 10, 1)
assert_true(#groups == 3, "expected 3 grouped ranges")
assert_true(groups[1].start == 1 and groups[1].stop == 3, "first group mismatch")
assert_true(groups[2].start == 8 and groups[2].stop == 9, "second group mismatch")
assert_true(groups[3].start == 20 and groups[3].count == 1, "third group mismatch")

local split = optimizer.group_registers({1, 2, 3, 4, 5, 6}, 4, 1)
assert_true(#split == 2, "max_group_size split failed")
assert_true(split[1].count == 4 and split[2].count == 2, "unexpected group sizes")

local normalized = optimizer.group_registers({5, "5", -1, "invalid", 6}, 10, 1)
assert_true(#normalized == 1, "invalid or duplicate register normalization failed")
assert_true(normalized[1].start == 5 and normalized[1].stop == 6, "normalized group mismatch")

cache.set("dev1", "hr", 10, 123)
cache.mark("status", "test")

local ok, err = cache.flush()
assert_true(ok, err or "cache flush failed")
assert_true(cache.get("dev1", "hr", 10) == 123, "cache get failed")

local file = io.open(runtime_dir .. "/cache.json", "r")
assert_true(file ~= nil, "cache file missing")
file:close()

local encoded = json.encode({message = "hello\nworld", enabled = true})
assert_true(encoded:find('"message":"hello\\nworld"', 1, true) ~= nil, "JSON escaping failed")
assert_true(encoded:find('"enabled":true', 1, true) ~= nil, "JSON boolean encoding failed")

local event_ok, event_err = events.record({kind = "test", message = "validation event"})
assert_true(event_ok, event_err or "event recording failed")

local event_file = io.open(runtime_dir .. "/events-core.jsonl", "r")
assert_true(event_file ~= nil, "events log missing")
local event_log = event_file:read("*a")
event_file:close()
assert_true(event_log:find("validation event", 1, true) ~= nil, "event was not written")

print("[test_core] OK")
