# Roadmap

## Diagnostics and control

- [x] Router-only core/demo integration and bounded event journal.
- [x] BluePill USB CDC register polling, validity state and recovery.
- [x] Minimal topic diagnostics: `modbus topics`, `modbus echo`, `modbus hz`.
- [ ] Safe DO/PWM writes through the core, with range validation and readback.
- [ ] Stable USB device identification and physical disconnect/reconnect tests.
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
