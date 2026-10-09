# Roadmap

## Current state and next steps

Core 0.4.0 and firmware map v2 implement router-driven button/LED control.
Completed work is summarized in [the stage archive](docs/archive/completed-stages.en.md).
This file lists remaining work; research stays local and push/land belong to the owner.

- [ ] Agree the independent core/demo/schoolbell drafts under `docs/core/` and `docs/packages/`; resolve or explicitly defer each component's questions.
- [ ] Prototype the shared event/subscription/scheduler/action API with mock clocks and providers; specify and version the core contract before integrating schoolbell.
- [ ] Measure serialization RAM and test filesystem failures; file bounds do not bound memory.
- [ ] Validate updated demo on hardware and measure its resources after separate installation approval.
- [ ] Agree custom runtime directory support for demo/CGI (demo question 8.2.1; core CGI question 9.2.3).

## Remaining work from the original plans

These are candidates to scope and agree, not approved runtime requirements.
The old FIFO examples, unconditional conffiles claims and SDK assumptions are
superseded by the current specification and validation notes.

- [ ] Write a module-author API guide for current JSONL topics, cache validity, Lua handlers, packaging and lifecycle; include a minimal example without direct serial access.
- [ ] Decide whether declarative JSON triggers and dynamically registered polling ranges are needed beyond the current trusted Lua handlers. A file listing and register-grouping helper do not implement this contract.
- [ ] Define and test configuration reload semantics: when restart is required, what state is retained, and whether module registration can change without interrupting polling.
- [ ] Define release/tag and core/demo versioning policy; add owner-triggered release publication with IPKs and checksums. Current CI builds branch artifacts only.
- [ ] Validate `make repo` and package index generation, then agree feed hosting, signing/trust and update/rollback checks. Do not disable signature verification or configure a router feed as part of documentation cleanup.
- [ ] Decide whether optional Ansible/IDE deployment integration and application modules (schoolbell/security/radio) belong in this repository; scope separately before implementation.

## Diagnostics and control

- [ ] Safe DO/PWM writes through the core, with range validation and readback.
- [ ] Extend the command allowlist to general DO/PWM with per-output safety policies.
- [ ] Durable command/event recovery semantics if replay across power failure is needed (current button example intentionally does not replay).
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
