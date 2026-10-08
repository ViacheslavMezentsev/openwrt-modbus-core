# openwrt-modbus-core

[Русский](README.md)

A lightweight Lua automation core for OpenWrt with Modbus RTU, state caching,
events and user handlers. Script-only IPKs are built without the OpenWrt SDK.

## Current state

- Core 0.4.0: UCI/procd, status CGI and bounded event journal in `/tmp`.
- Router-only demo; optional BluePill USB RTU polling of DI/DO/AI/PWM.
- `modbus topics`, `echo`, `hz` inspect publications without opening serial.
- WeAct BluePill Plus v1.1 STM32F103C8T6: PA0 button and PB2 system LED.
- Map v2 and Lua example: press counter -> event -> absolute FC05 LED write -> readback.
- Arduino CLI Maple DFU build checks application vectors at `0x08002000` and the 56 KiB limit.

Tested environment: WSL Ubuntu-20.04, OpenWrt 19.07.9 on MR3020 v3,
kernel 4.14.267, Lua 5.1. USB CDC is not electrical RS-485.
RTC and RS-485 gateway are future work; general DO/PWM core writes are not enabled.

## Build and verify

From the repository root in WSL:

```sh
make all
sh scripts/build-bluepill.sh
sh scripts/test-handlers-router.sh
make test-bluepill-router
make test-topics-router
```

The last three commands require router SSH (`ROUTER_HOST`, default `openwrt`).
Handler tests are isolated and do not open live USB; the others inspect the
running system. Without local Lua, `make all` skips Lua tests, not PASS.
CI explicitly installs Lua.

`make build`, `make build-demo`, `make verify`, `make repo` manage artifacts.
`make install-ipk`, `make test-opkg`, `make test-core-demo-router` modify the
router: agree on impact and configuration backup first. `make deploy-core` and
`make deploy-demo` are legacy unmanaged deployment, not the preferred path over
opkg. `make router-clean` removes temporary IPKs/caches; ensure no other process
needs them first.

## Router diagnostics

```sh
modbus topics
modbus echo /devices/1/sample --count 5 --duration 40
modbus hz /devices/1/sample --duration 30
modbus echo /devices/1/system/commands --duration 30
```

Replace `1` with the configured unit ID. Defaults: `profile=none`, system events
disabled. See [firmware/map](firmware/bluepill-modbus/README.md) and
[Lua events/setup](firmware/bluepill-modbus/ROUTER_EVENTS.md).

After confirming the port and agreeing on the UCI change, enable the profile:

```sh
uci set modbus-rtu-core.main.profile=bluepill
uci set modbus-rtu-core.main.device=/dev/ttyACM0
uci set modbus-rtu-core.main.baudrate=115200
uci set modbus-rtu-core.main.parity=N
uci set modbus-rtu-core.main.unit_id=1
uci set modbus-rtu-core.main.request_timeout_ms=500
uci commit modbus-rtu-core
/etc/init.d/modbus-rtu-core restart
```

For button control, additionally enable `system_events` as described in the events guide.

Cache addresses are zero-based. `meta.data_valid` describes the last complete
poll, `meta.last_success` its time; retained values become stale on failure.
System topics publish changes: age/hz describe events, not USB polling rate.
Old presses are not replayed after reconnect. `modbusd` is the sole serial owner.

Journal: `/tmp/modbus/events-core.jsonl` and `.1`, default 65536 bytes per segment,
configured by `event_log_max_bytes`. A single oversized entry is not rejected yet;
a strict bound needs follow-up (specification question 9.2.2). Slow subscribers can lose evicted events;
CLI warns about gaps. Monotonic intervals are independent of RTC/NTP.
`MODBUS_RUNTIME_DIR` overrides the diagnostics/test directory.

## Development

[Agent rules](AGENTS.md), [workflow and specifications](docs/DEVELOPMENT.en.md),
[roadmap](TODO.md), [changelog](CHANGELOG.en.md).
The Russian-only [technical specification, revision 1.0](docs/TECHNICAL_SPECIFICATION.md)
is a draft for agreement, with code/test traceability and explicit coverage gaps.
The owner performs push and land; land requires successful CI for the exact
branch HEAD. New PRs are not required. Research artifacts stay local.
