# Roadmap

## Current state and next steps

Core 0.4.0 and firmware map v2 implement router-driven button/LED control.
Completed work is summarized in [the stage archive](docs/archive/completed-stages.en.md).
This file lists remaining work; research stays local and push/land belong to the owner.

- [ ] Agree the independent core/demo/schoolbell drafts under `docs/core/` and `docs/packages/`; resolve or explicitly defer each component's questions.
- [ ] Measure serialization RAM and test filesystem failures; file bounds do not bound memory.
- [ ] Validate updated demo on hardware and measure its resources after separate installation approval.
- [ ] Agree custom runtime directory support for demo/CGI (demo question 8.2.1; core CGI question 9.2.3).

## Core and schoolbell development sequence

User-facing scope follows core draft 1.10 and schoolbell draft 1.4. A one-sample
engineering MVP is an intermediate result; replacement of the original requires
the complete schoolbell acceptance matrix. Details listed as open questions are
not silently approved by this sequence. API versions are independent of spec revisions.

- [ ] P00 — Finish the minimal API contract: the Unix stream v1/live-no-replay/session profile is accepted (core 1.10); finalize codec/field types, quotas, clock validity/correction, calendar boundaries and pause/pending policy. Record unresolved numeric budgets as measurements, not guarantees.
- [ ] P01 — Implement core public registration/publish/subscribe and a client adapter. Demonstrate fan-out to two independent clients, recovery, invalid replacement and slow-client isolation while polling continues (core TC-39/42/43/47/48/56/57/61–66). Keep current handlers/demo compatible.
- [ ] P01a — Integrate configurable safe-read retry count, per-attempt/total deadlines and bounded IPC servicing while waiting (core 6.2.4–6.2.7, TC-67/68). Keep writes non-replayed; resolve late-response resynchronization before enabling retries.
- [ ] P01b — Batch compatible due reads by transport/unit/function within safe map ranges and device/protocol limits (core 4.7, TC-69–71). Preserve deadlines, validity and write/readback barriers; the existing optimizer helper is not integrated.
- [ ] P02 — Design and implement offline bundle admission on an isolated filesystem: dependency closure/ABI/trust, RAM/storage peaks and reserves, bounded upload, staged activation and offline recovery (core TC-49–55). Select a concrete format before implementation.
- [ ] P03 — Implement the schoolbell-owned player worker, FIFO/expiry/cancellation and result events, scoped schedule controls and manual test (schoolbell TC-02/06–11/18). Resolve active stop separately; no audio API in core.
- [ ] P04 — Implement the common scheduler and system-time interface (core TC-58–60), then schoolbell fixed/annual modes, quiet days, preliminary bells, registration horizon and shared preview calculation (schoolbell TC-14–17). Browser clock synchronization is required; RTC is a separate enhancement for unattended startup.
- [ ] P05 — Implement schoolbell media IDs/revisions and bounded validated replacement with recovery (schoolbell TC-22/23). Preserve active/referenced files; the complete offline profile includes five original melodies plus test.
- [ ] P06 — Assemble the autonomous engineering MVP after P01–P05. Following separate hardware approval, validate install/update/rollback and event-to-playback/results while core/demo remain healthy. Validate reboot without Internet or previous /tmp; no claim of a full original replacement yet.
- [ ] P07 — Implement the local plan manager and desktop/mobile UI: year palette, schedule/row edits, explicit activation, controls, browser previews, router time, bounded system/package logs and dependency status (schoolbell TC-19–21/25–29). Browser closure must not stop scheduling.
- [ ] P08 — Implement versioned backup/restore and configuration/media migration (schoolbell TC-24); reject partial/incompatible data before activation. Legacy JSON/Base64 import is optional and requires its own reviewed conversion report.
- [ ] P09 — Validate the full schoolbell appendix B matrix and offline functional package (TC-12/13/30–33): five schedules, year plan, five melodies and 15 main + 6 preliminary moments. Measure resource peaks and scheduler/notification/process/audible latency separately; agree numerical bounds and hardware duration before acceptance.

Dependencies: P00 before P01/P02; P03 after P01; P04 uses P01 and P03 for end-to-end
checks; P05 follows the P00 media/storage decisions. P01a/P01b require their transport decisions before implementation; integrated P01
requires P01a so RTU waits do not starve IPC. P06 requires P01–P05 including P01a/P01b;
P07 follows P04/P06, P08 follows P02/P05–P07, P09 follows P06–P08.
Local fault tests precede hardware. Installation, sound, reboot, power loss and
long runs require separate authorization; this plan does not grant it.

## Remaining work from the original plans

These are candidates to scope and agree, not approved runtime requirements.
The old FIFO examples, unconditional conffiles claims and SDK assumptions are
superseded by the current specification and validation notes.

- [ ] Write a module-author API guide for current JSONL topics, cache validity, Lua handlers, packaging and lifecycle; include a minimal example without direct serial access.
- [ ] Decide whether declarative JSON triggers and dynamically registered polling ranges are needed beyond the current trusted Lua handlers. A file listing and register-grouping helper do not implement this contract.
- [ ] Define and test configuration reload semantics: when restart is required, what state is retained, and whether module registration can change without interrupting polling.
- [ ] Define release/tag and core/demo versioning policy; add owner-triggered release publication with IPKs and checksums. Current CI builds branch artifacts only.
- [ ] Validate `make repo` and package index generation, then agree feed hosting, signing/trust and update/rollback checks. Do not disable signature verification or configure a router feed as part of documentation cleanup.
- [ ] Decide whether optional Ansible/IDE deployment integration and further application modules (security/radio) belong in this repository; scope separately before implementation.

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
