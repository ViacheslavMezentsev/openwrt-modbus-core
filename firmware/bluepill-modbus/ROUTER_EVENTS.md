# Router Lua events (core 0.4.0)

Requires WeAct firmware map v2. No additional firmware update is required
after installing the system-register sketch. PB2 is written by the router,
not toggled locally by PA0.

## Enable and observe

The package defaults to disabled; enable only with compatible firmware:

```sh
uci set modbus-rtu-core.main.system_events=1
uci set modbus-rtu-core.main.system_poll_ms=200
uci commit modbus-rtu-core
/etc/init.d/modbus-rtu-core restart
modbus topics
modbus echo /devices/1/system/button --duration 30
modbus echo /devices/1/system/commands --duration 30
modbus echo /devices/1/system/led --duration 30
```

These three topics publish on changes/results, not every poll. Their age
is the age of the last EVENT, not the last USB read; `hz` on the button
measures event frequency, not the polling rate. A lost connection publishes
`valid=false`. The cache metadata also contains `system_button` and
`system_led` with their last event timestamps. General I/O sample delivery
remains unchanged. Logs stay in `/tmp` with the existing bounded rotation.

Only modbusd opens the serial port while this mode is enabled. It holds a
single nonblocking descriptor for both system and general I/O. Do not run
external serial diagnostics concurrently. Failed connections back off for
at least one second; a request has the configured bounded timeout. General
polling can add latency, so 200 ms is a target delay, not a real-time guarantee.

## Handler API

Place trusted local Lua source in `/etc/modbus-rtu-core/handlers.d/*.lua`.
Names may contain letters, digits, `_` and `-`. Restart the core to reload.
The bundled `button-led.lua` is an opkg conffile: preserve your edits on upgrade.

Each file returns `{topic = name, handle = function(event, ctx) ... end}`.
`UNIT_ID` is the configured device address. The example:

```lua
local prefix = '/devices/' .. UNIT_ID .. '/system/'
return {
    topic = prefix .. 'button',
    handle = function(event, ctx)
        if not event.valid or event.baseline or (event.presses_delta or 0) % 2 == 0 then return end
        local led = ctx.get(prefix .. 'led')
        if led and led.valid and led.age <= 1 then
            ctx.set(prefix .. 'led', not led.value)
        end
    end
}
```

- `ctx.topics()` returns names observed by this daemon since startup.
- `ctx.get(name)` returns a copy of the latest payload, plus monotonic `age`
  in seconds, or nil. System states are refreshed in memory on every poll.
  Check `valid` and `age`; general sample events have `values` instead of `value`.
- `ctx.set(name, boolean)` queues an absolute LED command. Only this unit's
  `/system/led` is writable in this release. It requires a valid snapshot
  no older than one second. Commands expire after one second.

Limits: eight loaded handlers, 32 KiB source per file, approximately 30000
Lua instructions per load/callback and eight queued commands. A callback
failure discards its staged commands, disables that handler until restart,
and publishes `/core/handler_errors`. Other handlers and polling continue.
No `os`, `io`, `require`, `debug`, sleeps or direct serial access are exposed.
This is for trusted administrator code, NOT a hostile-code security sandbox
or a hard memory limit. Keep scripts small and nonblocking. Multiple handlers
run in filename order; avoid competing writers to the same output.

## Delivery policy

Firmware counters retain short presses between reads. `presses_delta` is
the modulo-2^32 difference, with reset/discontinuity checks. Odd deltas
toggle the LED once; even deltas leave its final state unchanged. This
preserves final parity, not a visible flash for every accumulated press.
Releases and held buttons do not trigger additional writes.

First samples after daemon start, reconnect or detected MCU reset are
baselines: no old presses are replayed. On ambiguous write failure the
connection is invalidated, queued commands are discarded and the next
connection reads actual coil state. There is no claim of exactly-once
execution across disconnects or power loss. This prototype deliberately
prefers dropping uncertain presses to replaying them. Coil readback confirms
the firmware setpoint, not optical LED feedback.

## Tests

`sh scripts/test-handlers-router.sh` copies tests to a unique router `/tmp`
directory and runs the full Lua suite against fake ports. It does not touch
the live serial port or inject events into the live journal, and cleans up.
`make test` runs them locally when Lua 5.1 is installed.

For a physical test: three separate clicks, then one two-second hold should
produce four counter increments and four alternating successful commands,
ending in the original LED state. Inspect `/system/commands` and the button
counter; verify the LED visually. Restarting the core should add baseline
events, never an extra command.
