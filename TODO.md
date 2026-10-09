# Roadmap

## Current state and next steps

Core 0.4.0 and firmware map v2 implement router-driven button/LED control.
Completed stages are on main; research stays local and push/land belong to the owner.

- [x] Confirm signed commits through Windows Git and the owner-side `git land` alias in WSL (CI remains a manual prerequisite).
- [x] Draft Russian technical specification 1.0 using embedded-tech-spec, with traceability and explicit test gaps.
- [ ] Agree the draft in `docs/TECHNICAL_SPECIFICATION.md`; resolve or explicitly defer its open questions.
- [x] Run agreed USB power-cycle, MCU reset, core/router restart and two-hour passive observations; retain explicit coverage limits.
- [x] Promote restart/sequence regressions and accepted observations into specification draft 1.2 and RU/EN validation notes.
- [x] Reject oversized JSONL before rotation and verify byte bounds with unchanged limits and initially valid segments (spec question 9.2.2).
- [x] Test legacy oversized segments and lowering the journal limit; accept deferred rotation and legacy history loss (specification 1.3).
- [ ] Measure serialization RAM and test filesystem failures; file bounds do not bound memory.
- [ ] Test demo sequence discontinuities and agree custom runtime directory support (spec question 9.2.3).
- [x] Cover TTL expiry, map rejection, readback failure, snapshot isolation and handler API/limits with local regressions; specification revision 1.1.

## Diagnostics and control

- [x] Router-only core/demo integration and bounded event journal.
- [x] BluePill USB CDC register polling, validity state and recovery.
- [x] Minimal topic diagnostics: `modbus topics`, `modbus echo`, `modbus hz`.
- [ ] Safe DO/PWM writes through the core, with range validation and readback.
- [x] WeAct system button/LED via a trusted Lua handler, counter-based events and FC05 readback.
- [ ] Extend the command allowlist to general DO/PWM with per-output safety policies.
- [ ] Durable command/event recovery semantics if replay across power failure is needed (current button example intentionally does not replay).
- [x] Verify one isolated USB power-cycle recovery with unchanged tty name.
- [ ] Stable USB identification and recovery when the tty name changes.
- [ ] Firmware compile CI and register-map compatibility/version checks.

## Battery-backed RTC on the STM32 board

- [ ] Select an external RTC module and verify power, battery and interface wiring.
- [ ] Firmware commands to read/set RTC and expose time validity, oscillator and battery status where supported.
- [ ] Decide the authority and direction of clock synchronization between RTC, router and NTP.
- [ ] Preserve monotonic sampling timestamps alongside wall time; RTC/NTP corrections must not alter rate measurements.
- [ ] Test cold boot without network time, battery retention and invalid RTC recovery.

## STM32 as a serial gateway

- [ ] Support one or more downstream UART/RS-485 interfaces; choose pins, transceivers and direction control.
- [ ] Decide between core-driven request forwarding, board-side polling with cached tables, or a hybrid.
- [ ] Define interface/device addressing, capabilities and register-table discovery/versioning.
- [ ] Evaluate explicit configuration versus optional network discovery before polling.
- [ ] Evaluate a vendor-specific function or separate management protocol only after agreeing on interoperability needs.
- [ ] Bound queues, frame sizes, timeouts and retries; isolate failures and serialize each RS-485 bus.
- [ ] Return request IDs, exception/status codes, timestamps and data freshness to the core.
- [ ] Design access control and safe output behavior for link loss, reboot and conflicting requests.
- [ ] Measure RAM/Flash and router CPU/RAM costs with multiple devices.

Gateway protocol and discovery are intentionally undecided pending discussion.
The current USB RTU register map is a bench prototype, not a commitment to the gateway protocol.

## Firmware maintenance

- [ ] Investigate simple router-assisted firmware updates after laptop flashing is stable.
- [ ] Select a bootloader/update transport, image verification and recovery procedure.
