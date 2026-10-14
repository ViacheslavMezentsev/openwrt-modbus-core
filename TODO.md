# Roadmap

## Current state and next steps

Core 0.4.0 and firmware map v2 implement router-driven button/LED control.
Completed work is summarized in [the stage archive](docs/archive/completed-stages.en.md).
This file lists remaining work; research stays local and push/land belong to the owner.

- [ ] Agree the independent core/demo/schoolbell drafts under `docs/core/` and `docs/packages/`; resolve or explicitly defer each component's questions.
- [ ] Measure serialization RAM and test filesystem failures; file bounds do not bound memory.
- [ ] Validate updated demo on hardware and measure its resources after separate installation approval.
- [ ] Agree custom runtime directory support for demo/CGI (demo question 8.2.1; core CGI question 9.2.3).

- [x] Split CI by core/demo/schoolbell with conservative change selection, mandatory ci-gate and offline documentation/specification checks. Local component targets and filter/gate regressions are available.

## Core and schoolbell development sequence

User-facing scope follows core draft 1.26 and schoolbell draft 1.5. A one-sample
engineering MVP is an intermediate result; replacement of the original requires
the complete schoolbell acceptance matrix. Details listed as open questions are
not silently approved by this sequence. API versions are independent of spec revisions.

- [ ] P00 — Finish the minimal API contract: the Unix stream v1/live-no-replay/session profile is accepted (core 1.10); finalize codec/field types, quotas, clock validity/correction, calendar boundaries and pause/pending policy. Record unresolved numeric budgets as measurements, not guarantees.
- [x] P01 registry foundation — isolated Lua sessions/types/subscriptions, atomic replacement, generations and copied recipient snapshots; 17 local tests. No transport/publish/ack integration yet.
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

## Multiport rounds — separate branches

Accepted core 1.13 requirements: section 4.8. Revision 1.14 records partial host-model coverage of TC-74–82; integration and TC-83 remain planned.
This sequence expands P01a/P01b; it does not mark them complete or authorize hardware changes.

- [x] M00 — Record round/barrier semantics, per-port identity, compatibility and acceptance criteria; documentation only.
- [x] M01 model — Deterministic host model for 1/2/3 transports, barrier/service timing, abstract errors and sequential comparison; 16 tests, partial TC-74–82. No serial bytes, grouping, retries or runtime integration.
- [x] M01 contract draft — Prepare [RTU/TCP deadlines, recovery, configuration and round criteria](docs/core/TRANSPORT_CONTRACT.en.md), core 1.19 / TC-111–122. Documentation only.
- [x] M01 decisions — Owner accepted transport contract 1.19: deadlines, recovery, configuration and software budgets. Hardware timing evidence, USB resolver and IPC wire limits remain integration prerequisites.
- [x] M02 states — Host-only RTU/TCP state model and 37 clock/byte tests; partial TC-111–115/120/121. Not a runtime driver; no UCI loader or hardware access.
- [x] M02 scheduler — Compose isolated states with FIFO, fixed RTU rounds, independent TCP, periodic coalescing and pass quotas; 15 host tests, partial TC-117–119. No real I/O/IPC or grouping.
- [x] M02 grouping — Accepted safe ranges and implemented host FIFO grouping, limits/splitting and fan-out; 20 tests, partial TC-69–71/119. Writes unchanged.
- [x] M02 profile loader — Accepted JSON profile/assembly limits; strict host loader, all-or-nothing activation, packed assembly/reservations and 21 tests. No router paths or runtime changes.
- [x] M02 strict JSON — Bundled Lua 5.1 decoder, null/container types, bounded parsing and 20 test groups. Legacy consumers unchanged.
- [x] M02 Lua profile schema — Strict schema/defaults/overlap checks, bounded shared candidates and atomic publication via injected reader; 19 Lua test groups. No production filesystem adapter or modbusd integration.
- [x] M02 safe reader — Linux/nixio trusted directory walk, no-follow, descriptor checks, bounds and cleanup; 13 fault groups plus native host file/race/FD tests. No modbusd or router changes.
- [ ] M02 map integration — Validate reader on target after approval, coordinate installer exclusion/package provenance and connect the Lua loader; add evidenced device profiles and measure total Lua memory/serialization peaks. Host profiles do not establish device safety or atomic snapshots.
- [ ] M02 backend — Port the accepted state contract to the production Lua/backend boundary with fake I/O tests, generation guards and bounded TX completion before M03.
- [ ] M03 — Integrate validated multiport configuration, diagnostics, legacy compatibility and event servicing into modbusd after M01/M02; finalize addressing before integration.
- [ ] M04 — After separate installation approval, run the single-port regression with the existing BluePill. Later use the separate Serial Monster board as a gateway to agreed external RTU responders for multiport hardware checks.

One finished scope per branch; owner push, exact-HEAD CI and land precede the next branch.
FreeRTOS/new MCU firmware is separate work; the current board is sufficient for legacy checks.

## Transport and gateway architecture — separate branches

- [x] G00 — Core 1.15 architecture: logical identity, endpoint/unit routing, port roles, TCP client and standard offline RNDIS distribution. No runtime implementation.
- [x] G01 — Accepted transport contract 1.19: direct RTU/TCP configuration, legacy migration, deadlines and late responses; TCP independent of RTU rounds.
- [ ] G02 — Host state model now covers bounded TCP framing, transaction/connection identity and disconnect semantics; implement the real socket backend with fake I/O tests before claiming a working client.
- [ ] G03 — Integrate RTU/TCP logical devices and diagnostics after G01/G02 and required M stages; decide mixed scheduling before implementation.
- [ ] G04 — Implement the platform-specific offline RNDIS bundle with dependency closure, exact kernel ABI/trust/space validation and preserved network settings; coordinate with P02 admission work.
- [ ] G05 — Create a separate gateway specification before firmware: route/role management API, filters, shared line queues, persistent configuration and autonomous operation. Monitor/bridge are later stages.
- [ ] G06 — After separate approval, validate BlackPill Modbus TCP over RNDIS, external RTU routes and offline installation/reboot. Existing HTTP observation does not close these cases.
- [x] C00 — Accept core 1.16 settings requirements: persistence/import, package-owned schemas/migrations, fleet templates versus backups; schoolbell 1.5 owns application validation. No implementation.
- [x] C01 format — Core 1.17 separates package.json, plain settings.json and settings.schema.json; package-context API with opaque concurrency token. No implementation.
- [ ] C01 details — Complete core 9.2.26: JSON fields/types/limits, API, concurrency/revisions, permissions/secrets, file manifest and durable activation/recovery before coding.
- [ ] C02 — Implement the isolated shared mechanism and failure tests, then package-specific schema/migrations in separate branches; hardware power-loss tests need separate approval.

## Extension admission and later scenario research

- [x] A00 — Core 1.18 minimal manifest and bundle admission requirements; generated inventory, trust, bounded unpacking, declarative extension installation. No implementation.
- [ ] A01 — Resolve core 9.2.27 before coding: exact schema/version grammar, permissions enforcement, trust/signatures, archive/path limits, stock IPK hooks and recovery. Coordinate with P02/G04.
- [ ] A02 — Implement admission on an isolated filesystem with negative/failure tests before any approved hardware installation.
- [ ] V00 — Next separate local research: lightweight DI/DO/AI/AO visual scenarios, browser editor and bounded runtime. No implementation or inclusion in mandatory core distribution is authorized by this manifest stage.

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

Gateway address/role architecture is accepted in core 1.15; exact management protocol, discovery and firmware remain undecided.
The current USB RTU register map is a bench prototype, not a commitment to the gateway protocol.

## Firmware maintenance

- [ ] Investigate simple router-assisted firmware updates after laptop flashing is stable.
- [ ] Select a bootloader/update transport, image verification and recovery procedure.

## Router boot and recovery

- [x] Document MR3020 v3 versus v3.30 evidence, UART diagnostics and Windows TFTP workflow in paired public guides; provide an offline SHA-256 staging helper.
- [ ] After separate approval, capture the failing release's UART log and verify v3.30 recovery filename/server address and rollback; preserve raw evidence locally.
- [ ] Resolve region-specific v3.30 OEM recovery format/downgrade restrictions before any conversion or flashing; do not infer TFTP suitability from a web-update file.
- [ ] If needed, design a Windows adapter/firewall helper with persistent original-state recovery and host tests; current helper only stages an image, Tftpd64 waits for the router.

## MR3020 platform console

- [x] Preserve owner-provided MOTD and mode/debug handlers as platform source assets with read-only hash verification and RU/EN limitations.
- [ ] Agree a separate mr3020-console package contract before implementation: board/version checks, interactive output, switch startup state, dependencies and coexistence with slide-switch, file ownership/conffiles and reversible install/remove. Current assets are not installed or built into IPKs.

- [ ] Design a separate `mr3020-modes` package: configurable physical-position-to-profile mapping; developer Ethernet/DHCP profile preserving current access and standalone secured Wi-Fi AP with local DHCP/web access without Internet. Define boot selection, debounce, validation, active/requested status, rollback and coexistence with slide-switch. Application packages may propose templates; a single platform service owns network activation. Third switch position remains undecided. Keep MOTD independent; no network changes authorized by this TODO.

- [x] Refresh MR3020 MOTD with the original logo and full status sections; preserve legacy, install with verified backup, check interactive and noninteractive SSH. No package or reboot validation yet.

## Distributed router gateway candidate

- [ ] Research an optional router-owned Modbus TCP server/gateway: central client/AP and remote Ethernet routers with RS-485 lines. Define endpoint/unit-to-line/unit routes, serialized shared line access, client quotas, permissions/write ownership, timeout propagation, cache freshness and loop prevention. Current contract is client-only; Wi-Fi/network configuration and server implementation require separate scope.
