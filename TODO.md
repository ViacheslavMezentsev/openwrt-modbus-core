# Roadmap

## Current state and next steps

- [x] 5.1.8 host: passive tab-local API traffic chart, 12 x 5s bins, latency-to-headers/error/pending metrics, shared Pages and controlled-clock tests.
- [ ] Accept the chart on device; use observed HTTP timings to guide investigation before changing polling/worker exchange. Internal executor timings are not measured.

- [x] 5.1.7 host: explicit browser/Shkolnik audio routes and a collapsed warning-colored draft panel; shared Pages UI.
- [ ] Accept 5.1.7 layout on device after separate installation approval.

- [x] Calendar acceptance through Shkolnik 5.1.2: named non-overlapping calendar ranges, consecutive month pages, synchronized top/bottom navigation and device-neutral save label. Owner confirmed cross-year viewing, paging, painting persistence, save/reload and both navigation panels. Automatic bells remain off. Pages publication is a separate owner action; local demo is synchronized with the current sources.
- [x] Range model shared by Lua storage/preview/executor, backup and Pages; legacy checksums preserved on read. Target installation backed up and payload/data checked. This does not close full power-loss or security acceptance.
- [x] Release discovery/update requirements: core 1.34 / schoolbell 1.54, stable package identity and dependencies, simple notification UI and separate administrator installation. Documentation only; current IPK has no updater.
- [x] Signed manifest/API requirements: core 1.35 / schoolbell 1.55, exact-byte Ed25519, bounded discovery, independent modules, shared dependencies and platform-specific builds. Documentation only.
- [x] Isolated strict manifest/discovery host model: 32 tests with fake network/clock/verifier/opkg comparator, deadline and input bounds, dependency/reissue conflicts and partial results. Core specification 1.36; no real crypto/HTTP or updater.
- [ ] Next update stage: select verifier/key delivery and HTTPS/redirect/Link protections, real opkg comparator, wire/ACL, memory/cache/backoff and recovery (core 9.2.31); then integrate isolated adapters. No automatic installation.
- [x] Shkolnik 5.1.3 host implementation: compact header Auto bells button, confirmed colored status, retained applied copy and revision/generation-checked resume. Draft remains separate; shared Pages simulation, quick guide and specification 1.56 updated.
- [x] Install 5.1.3 after backup; owner confirmed header button and yellow no-applied-plan status with automatic bells off.
- [x] 5.1.5 installed after verified backup/rollback: automatic status below the full header button group, left-aligned text-sized background, shared Pages layout.
- [x] 5.1.6 host: “Resolve problem” explains state and provides read-only refresh/safe navigation; no automatic enabling, clock changes, bypassing time control or lock deletion. Neutral device wording and technical copy IDs kept out of primary status; Pages synchronized.
- [ ] Accept 5.1.6 diagnostic routes on device after separate installation approval, including expired sessions, stale state and preserving unsaved edits.
- [x] Owner accepted 5.1.5 header resume/stop of the retained applied plan: green running and yellow disabled; four running samples over 12 seconds retained confirmed clock trust. Final auto off, applied copy retained, backup byte-identical and system/NTP guard unchanged.
- [ ] Extend acceptance beyond the short quiet-day test: large plans, sustained load, repeated transitions and audible scheduled bells. The 5.1.4 observation-gap failure motivated bounded SHA caching/cooperative observation; the short 5.1.5 check is not a long-run guarantee.
- [ ] Next application feature: portable plan export/import with dependency closure and compatibility preview. Pages first stage uses bundled melodies only. Archive not implemented.
- [ ] Verify real LuCI expiry/logout/CSRF/unauthenticated endpoints, concurrent tabs and suspended browsers. Owner accepted compact login and 5.0.36 styling; that does not certify the full security matrix. Current installed 5.1.5 includes the later logout fix.

- [ ] Next schoolbell feature accepted by owner: portable annual/academic-plan bundle with selected named date ranges, date assignments, referenced schedules/colors, pre-bell parameters and all referenced media. September–May spans two calendar years. Reuse backup/media mechanisms; preview dependency closure and conflicts before import, validate plan timezone without applying system timezone, import only as draft with automatic bells disabled. Exclude credentials, network, NTP/clock and hardware-specific settings; specify bundled-media compatibility and atomic rollback before implementation.

- [x] S1 revised in 5.0.35: same-tab login with bounded sessionStorage draft handoff; compact controls, idle preference in Settings, no visible countdown; Pages shares the change.
- [x] Owner confirmed same-tab login preserves the edited name in 5.0.35 and accepted 5.0.36 styling. Current package includes subsequent fixes; the security matrix below remains open.
- [x] Named-range calendar is now the working shared Pages/router editor, superseding the prototype; trusted date only proposes September–May.
- [x] Range format installed and tested through 5.1.2; persistence and month navigation accepted by owner. Complete portable bundle remains pending.
- [ ] S1 target acceptance: real LuCI expiry/logout/CSRF/unauthenticated endpoints, multiple tabs and suspended browser; browser timer is not server policy. Do not infer security acceptance from successful installation.

- [x] Shared first-tab quick guide for router UI and Pages; owner confirmed display and tab switching. Independent operator acceptance remains below.

- [x] Static [UI completeness/security plan](docs/packages/schoolbell/UI_COMPLETENESS.en.md): UX-01–12, proposed C1–C6/S1–S2, endpoint acceptance SEC-01–06; no live security certification.
- [x] C1 initial UI: fixed/annual deletion guards, explicit last-year transition and two-copy reconciliation with CAS; shared Pages regressions, host-only 5.0.32.
- [ ] C1 remaining / S1: accept referenced-schedule deletion and last-plan transition where not yet demonstrated; audit session/CSRF/logout/expiry. Calendar editing/persistence and Pages publication are confirmed; dependency navigation and other UX items remain.
- [ ] Agree and implement C2–C6/S2 separately: browser clock setting, active preview, safe media rename/delete, bounded undo, complete import/onboarding and server-enforced roles/TLS profile. Do not grant root credentials as a substitute for operator permissions.


- [x] RU/EN Markdown guide covers named ranges, month pages, draft/active separation and current interface; installed router is 5.1.2. Startup/time and browser-preview limitations remain explicit.
- [ ] Validate the guide with an independent operator on desktop/touch during AC-10/12; documentation alone does not close usability acceptance.

- [x] Draft [schoolbell 5.x acceptance programme](docs/packages/schoolbell/ACCEPTANCE.en.md): AC-01–12, appendix B parity, release blockers and evidence rules; documentation only, not product PASS.
- [ ] Agree acceptance Q1–Q5: numerical timing/resource/accuracy budgets, endurance duration, collision policy and attended-startup release scope. Existing production dependencies below remain until explicit scope agreement.
- [x] Schoolbell startup/boot/TZ audit: 11 additional host worker scenarios and independent 15+6 calendar oracle; see [audit](docs/packages/schoolbell/STARTUP_AUDIT.en.md).
- [ ] AC-06 hardware acceptance remains open. Cold boot/power and sound acceptance require separate authorization; the clock measurement is closed. Do not change NTP.
- [ ] Execute the agreed AC programme and reconcile the operator/install/recovery guides with shipped behavior before release; historical stage descriptions are not current acceptance results.


- [x] Schoolbell safe date viewing and explicit draft/active-plan separation: clean saved revision gating, race/error tests and browser demo. Version 5.0.16 installed; target date-viewing and status separation confirmed by the user.
- [x] Backup download deadline and recovery controls, controlled-network regressions; Pages build date/commit. Version 5.0.17 installed; user confirmed download; installed JS tested with a local HTTP body disconnect.
- [x] Media auto-refresh after confirmed upload, per-row browser listening and empty-slot labels; six bundled demo melodies, host-tested in 5.0.18. LuCI streaming fix 5.0.19 adds yielding source/sink regressions.
- [x] Validate media upload/listening routes on the router: browser upload and listening confirmed; CGI compatibility fixed in 5.0.22/23. Physical network disconnection was not used for the backup test.

- [x] Engineering automatic schoolbell service: explicit saved fixed/annual snapshot activation, Mute and no catch-up. Host tests and target commissioning are documented separately.
- [ ] Measure audible auto-bell/Mute latency and long-run resources; integrate the production player/core scheduler and validate the installed clock gate after cold startup before unattended operation across power loss.

- [x] Owner published/updated the Pages site; keep publishing each approved main using the manual workflow (site/README.md).
- [ ] Verify schoolbell timezone handling on zoneinfo-file targets; the POSIX TZ target has passed live application through the UI.

- [x] Connect duty countdown to the engineering executor (today horizon); drafts remain separate.
- [ ] Extend countdown to future assigned days and subscribe the package journal to core system events.

Core 0.4.0 and firmware map v2 implement router-driven button/LED control.
Completed work is summarized in [the stage archive](docs/archive/completed-stages.en.md).
This file lists remaining work; research stays local and push/land belong to the owner.

- [ ] Agree the independent core/demo/schoolbell drafts under `docs/core/` and `docs/packages/`; resolve or explicitly defer each component's questions.
- [ ] Measure serialization RAM and test filesystem failures; file bounds do not bound memory.
- [ ] Validate updated demo on hardware and measure its resources after separate installation approval.
- [ ] Agree custom runtime directory support for demo/CGI (demo question 8.2.1; core CGI question 9.2.3).

- [x] Split CI by core/demo/schoolbell with conservative change selection, mandatory ci-gate and offline documentation/specification checks. Local component targets and filter/gate regressions are available.

## Core and schoolbell development sequence

User-facing scope follows core draft 1.36 and schoolbell draft 1.56.
The engineering application is packaged and installed as 5.1.5 with an offline
OpenWrt 19.07.9 bundle. Core event API and production player integration remain separate.

- [ ] P00 — Finish the minimal API contract: the Unix stream v1/live-no-replay/session profile is accepted (core 1.10); finalize codec/field types, quotas, clock validity/correction, calendar boundaries and pause/pending policy. Record unresolved numeric budgets as measurements, not guarantees.
- [x] P01 registry foundation — isolated Lua sessions/types/subscriptions, atomic replacement, generations and copied recipient snapshots; 17 local tests. No transport/publish/ack integration yet.
- [ ] P01 — Implement core public registration/publish/subscribe and a client adapter. Demonstrate fan-out to two independent clients, recovery, invalid replacement and slow-client isolation while polling continues (core TC-39/42/43/47/48/56/57/61–66). Keep current handlers/demo compatible.
- [ ] P01a — Integrate configurable safe-read retry count, per-attempt/total deadlines and bounded IPC servicing while waiting (core 6.2.4–6.2.7, TC-67/68). Keep writes non-replayed; resolve late-response resynchronization before enabling retries.
- [ ] P01b — Batch compatible due reads by transport/unit/function within safe map ranges and device/protocol limits (core 4.7, TC-69–71). Preserve deadlines, validity and write/readback barriers; the existing optimizer helper is not integrated.
- [ ] P02 — Design and implement offline bundle admission on an isolated filesystem: dependency closure/ABI/trust, RAM/storage peaks and reserves, bounded upload, staged activation and offline recovery (core TC-49–55). Select a concrete format before implementation.
- [x] P03 queue foundation — Isolated Lua FIFO, TTL/UTC checks, owner cancellation, bounded receipts and injectable player; 24 host test groups. Unknown process outcomes retain the resource. No core, process, media retention or sound integration.
- [x] P03 player contract — schoolbell 1.8 accepts process launch/completion, pinned media revisions and crash blocking; TC-43–49 planned, no runtime changes.
- [x] P03 system mechanisms contract — schoolbell 1.9 accepts native fork/exec, inherited flock, protected file via stdin, begin/poll/release, 2000 ms timeout and /dev/null; no implementation.
- [x] P03 results and budgets contract — schoolbell 1.10: exact snapshots/errors, executable-identity exec evidence, 16-byte control frame, 64/64/8/8 operation limits; TC-56–60 planned.
- [x] P03 wire and parameter contract — schoolbell 1.11: SBPE/v1 big-endian, generation/attempt rules and strict ranges; TC-61–65 planned, no implementation.
- [x] P03 isolated codec/API — Lua SBPE codec and injected player model; 32 host groups cover frame splits, randomness failure, foreign handles, counter exhaustion, outcomes and bounded cleanup. No native/process/audio/core integration.
- [x] P03 standalone Linux adapter — C library and substitute child, 13 host process/fault groups; no audio device, Lua/core/IPK integration or router changes.
- [x] P03 isolated Lua binding — Lua 5.1 userdata, copied results and recoverable retained handles; eight fixture-process groups including GC/OOM. No queue/core/audio/router integration.
- [x] P03 queue/Linux composition — Dedicated bridge with launching/finishing, signal outcomes and recoverable begin/release results; 10 fixture-child groups. No core/audio/router/IPK integration; exact media FD is borrowed from trusted host storage.
- [ ] P03 system integration — Implement durable media publication and reference recovery; getrandom/CLOCK_MONOTONIC are implemented on the host; verify actual madplay lock FD/stdin and target /proc before real-process integration.
- [ ] P03 — Implement the schoolbell-owned player worker, FIFO/expiry/cancellation and result events, scoped schedule controls and manual test (schoolbell TC-02/06–11/18). Resolve active stop separately; no audio API in core.
- [x] P04 calendar calculation — Isolated schoolbell Lua snapshot/calculator, fixed and explicit annual selection, quiet-day midnight suppression, no annual repeat and gap/fold rejection; 29 groups plus 14,404 independent date vectors, original 15+6 across a leap year. No core registration, UI, player, storage or hardware acceptance; full appendix B parity still required.
- [ ] P04 — Implement the common scheduler and system-time interface (core TC-58–60), then connect the existing engineering fixed/annual calculator, quiet days and preliminary bells to its registration horizon/shared preview (schoolbell TC-14–17). Browser clock synchronization is required; RTC is a separate enhancement for unattended startup.
- [x] P05 engineering upload — six protected bundled slots and eight user slots through the media manager, bounded MP3/decoder validation, inactive-auto/shared-gate admission and CAS; engineering backup/restore with user MP3 passed in 5.0.24; production revision-pinned plans and migrations remain pending.
- [ ] P05 — Implement schoolbell media IDs/revisions and bounded validated replacement with recovery (schoolbell TC-22/23). Preserve active/referenced files; the complete offline profile includes five original melodies plus test.
- [x] P06 engineering packaging — full 5.0.28 IPK, native dependency, pinned offline closure and joint core manifest; host installation/upgrade/rollback and fail-closed tests.
- [x] P06 target packaging — real opkg migration, local recovery downgrade and upgrade to 5.0.31; full payload hashes and byte-identical backup confirm retained settings/plans/user MP3 with auto-off. Fixed missing stat, omitted directory entries and stale LuCI bytecode; dependencies/core/NTP unchanged.
- [x] P06 browser migration check — owner confirmed 5.0.31, retained schedules/year plan/user melody and auto-off after reload.
- [ ] P06 remaining acceptance — separately approve reboot/offline-first-boot/power-loss and full dependency installation on a clean target. Production event/player integration remains dependent on P01–P05.
- [x] P07 saved schedule editor — Create/copy/delete/edit rows and persistent inactive drafts, content-revision conflicts and strict calendar validation; host/target filesystem checks. Initial editor stage used test.mp3 only; annual/media/activation work followed in the entries above. [Details](docs/packages/schoolbell/SCHEDULE_EDITOR.en.md).
- [x] P07 annual draft — Twelve-month grid, date/range assignment, up to eight explicit years, shared persistence and civil preview through Lua calendar. Legacy read is unchanged; no UTC/DST or activation. [Details](docs/packages/schoolbell/ANNUAL_CALENDAR.en.md).
- [ ] P07 editor integration — Validate timezone/DST and clock quality, then migrate inactive drafts into the validated production snapshot/media contract before activation. Do not silently treat editor checkpoints as active plans or backup/import format.
- [x] P07 manual sound page — LuCI login/CSRF, explicit browser/router routes, fixed sample and guarded diagnostic player; both routes confirmed on MR3020. The initial diagnostic stage preceded engineering scheduling and the full IPK; production worker integration remains pending. See [router-page](packages/schoolbell/router-page/README.en.md).
- [x] P07 visual mockup — Accepted standalone calendar/schedules/media/player views and system/dark/light themes in [ui-mockup](packages/schoolbell/ui-mockup/README.en.md). Synthetic data only; no API/audio/router/IPK integration. This does not complete functional UI acceptance.
- [ ] P07 production acceptance — engineering year palette, schedule edits, explicit activation, controls, browser previews, router time and bounded journal exist; finish mobile/DST/production snapshot acceptance and core system-event subscription (schoolbell TC-19–21/25–29).
- [ ] P08 — Complete production configuration/media migration and admission beyond the engineering backup/restore validated in 5.0.24 (schoolbell TC-24); reject partial/incompatible data before activation. Legacy JSON/Base64 import is optional and requires its own reviewed conversion report.
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
- [x] M02 reader target — Accepted isolated c68dec5 verification on OpenWrt 19.07.9/MIPS: 52 Lua test groups, native filesystem/races/FD stability and reader-to-loader; installed core unchanged.
- [ ] M02 map integration — Coordinate installer exclusion/package provenance and connect the Lua loader; add evidenced device profiles and measure total Lua memory/serialization peaks. Host profiles do not establish device safety or atomic snapshots.
- [x] M02 Lua states — Port isolated RTU/TCP states with injected monotonic clock and byte-completion I/O; 30 Lua test groups. No native backend, scheduler or modbusd.
- [x] M02 Lua composition — FIFO, fixed RTU rounds, independent TCP, coalescing, expiry and pass quotas with fake byte I/O; 19 Lua test groups (TC-132). Synthetic IPC only; no runtime integration.
- [x] M02 Lua grouping — Validated profile snapshot, compatible FIFO reads, lazy fragments, packed assembly/fan-out and shared payload reservations; 26 Lua test groups (TC-133). No runtime/native I/O or hardware changes.
- [ ] M02 Lua memory — Measure total Lua allocation/GC peaks for profiles, maximum concurrent assemblies, bit packing and fan-out; payload reservations exclude transient strings, byte tables, results and I/O. Agree target limits before runtime integration.
- [x] M02 I/O contract — Accepted core 1.31 system-I/O requirements and planned TC-134–139; operation/attempt identity, pre-write validity, bounded execution and cleanup. Documentation only.
- [x] M02 I/O host/API — Accepted four-call budget and native dependency; isolated injected Lua API with 20 test groups, host mechanism probes and pinned nixio audit (TC-140/141). No native implementation or scheduler integration.
- [x] M02 native primitives — Isolated Linux C single-call library, separate build and host/fault tests (TC-142/143). No Lua binding, target ABI/IPK, scheduler/modbusd or hardware changes.
- [ ] M02 I/O details — Add the Lua binding; verify target ABI and bounded setup/close/TX completion, then connect token/wakeup API to states/scheduler with fake-I/O tests; measure total RAM. Host capabilities do not prove target timing.
- [ ] M02 command contract — Resolve core 9.2.30 separately: expiring permissions to the board, setpoint replacement/results and STOP priority versus rounds/resources. Existing FIFO/resync is unchanged; rover watchdog is board-owned.
- [ ] M02 native backend — Implement bounded serial/socket setup/TX completion and generation-aware event delivery, after defining the driver contract; no modbusd/hardware changes without the corresponding stage.
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


## Rover example package — separate branches

- [x] R00 — Independent rover specification 1.0: two differential-drive bases, Wi-Fi browser video overlay and RTU/TCP. Safety proposals require agreement; no runtime/IPK.
- [ ] R01 — Agree hardware, mixer, TTL/watchdog, arm/disarm, session ownership and video-loss policy (rover 8.2).
- [ ] R02 — Implement mixer/session/stale-command/stop tests with fake I/O; no motors.
- [ ] R03 — Prototype isolated local UI/video; measure CPU/RAM, freshness and latency before selecting streaming format/dependencies.
- [ ] R04 — Agree generic safe writes and queues with core, board map, atomic setpoints/ack and independent watchdog before RTU/TCP motor integration.
- [ ] R05 — Prepare offline bundle, settings/import and explicit Wi-Fi setup via mr3020-modes; installation must not arm motors or silently change networking.
- [ ] R06 — After separate approval, test with lifted wheels, independent drive-power cutoff and measured watchdog/video-loss stops; ground driving follows separately.

Rover does not replace pending core native-I/O and Lua memory work.

- [x] P03 media admission foundation — exact revision lease at submit, nine host groups (TC-72); bounded in-memory native catalog, no durable media recovery.
- [x] Schoolbell settings mockup — separate browser and router speaker diagrams with explicitly simulated buttons; no audio/API.

- [x] P03 persistent media policy — schoolbell 1.17: immutable files, consistent bundles, streamed bounded upload, durable acknowledgement, paused fallback, no queue replay, reference-safe cleanup. TC-73–82 planned; requirements only.
- [x] P03 media format/quota/commit contract — schoolbell 1.18 accepts strict JSON, SHA-256 revision identity, persistent layout, protective quotas and current/recovery publication order. TC-83–90 planned; no implementation.
- [x] P03 prepared storage mechanisms — exact pointers/checksums, descriptor, initialization, commit/recovery and recovery-pointer cleanup implemented in isolated manager (schoolbell 1.19). Production settings/plan schemas, validation, ownership and resource integration remain below.
- [ ] P03 full persistent media acceptance — TC-91/92 cover prepared storage and 25 process-crash points on host/router; complete TC-73–90 for production integration and all quota boundaries. Actual power-loss tests require separate hardware approval.

- [x] P03 isolated media manager — prepared user objects, strict pointer/descriptor validation, durable publication/recovery/cleanup and 25 host process-crash checkpoints. No MP3 validator, core/queue integration or power-loss guarantee.
- [ ] P03 media production integration — real settings/calendar schemas, validated uploads/bundled resolver, operation ID generator/retention, explicit fallback confirmation, process/backup ownership, queue FD leases, decoder capacity and total RAM/FD measurements. Current prepared dependency manifests are not user plans.

- [x] P03 isolated router storage check — TC-92 passed on MR3020 in tmpfs and an isolated persistent directory, 25 process-crash checkpoints each plus negative tests; cleanup verified, core/demo preserved. This does not validate power-loss durability or install schoolbell.

- [x] Schoolbell: инженерный backup сохранённого плана/настроек/пользовательских MP3, восстановление с autooff; восемь слотов и названия (5.0.14).
- [ ] Schoolbell: отдельный шаблон партии; production-привязка активных планов к ревизиям медиатеки и восстановление после аппаратного сбоя питания.
- [x] Schoolbell: принят контракт clock trust/rollback (ТЗ 1.31, CLOCK_TRUST.md), TC-113–119 плановые; без реализации и изменений роутера.
- [x] Schoolbell: принят clock/1, предел 1024 байта, запись 3600 с, наблюдение 1000/3000/100 мс, пороги 1–60 с и подтверждение 15000 мс (ТЗ 1.32); TC-120–124 плановые.
- [x] Schoolbell: изолированные кодек UTC-ms, CAS-хранилище и модель clock trust с fake clock/storage, границами и отказами фиксации (ТЗ 1.33).
- [x] Schoolbell: изолированный системный адаптер BOOTTIME/REALTIME и приватного FD-хранилища; host-тесты и syscall faults (ТЗ 1.34).
- [x] Schoolbell: изолированная target-проверка clock/FS адаптера в tmpfs и постоянном каталоге выполнена; рабочий пакет не менялся.
- [x] Schoolbell 5.0.25: clock gate подключён к коду исполнителя/ожиданию player; отключаемый режим и host-регрессии. Доставлен на стенд в 5.0.26/27.
- [x] Schoolbell 5.0.26: отдельный native clock IPK, worker/API/UI подтверждения и отключения контроля, host-тесты; последующая target-проверка 5.0.27 указана ниже.
- [x] Schoolbell: установлены native clock1.0.0 и5.0.26, затем исправление5.0.27; подтверждение/restart/bypass и реальная конкуренция GET проверены, пользователь подтвердил браузерный маршрут. Автозвонки выключены, часы/NTP не менялись.
- [x] Переносимый навык skills/router-clock-drift: RAW/NTP метод, probe/collector, интервальный анализ и self-test; без реальных данных в Git.
- [ ] Schoolbell: NTP/RTC-критерии подтверждения, предел неопределённости и срок автономного доверия после измерений; без обещания годовой точности по суточному опыту.

- [x] Schoolbell 5.0.15: жёлтая полоса места >75%, красная >90%, текстовое предупреждение; без установки.
- [x] Schoolbell: просмотр дня без правки, разделение черновика/активного плана, обновление после загрузки мелодии и ограниченное скачивание backup реализованы и проверены на роутере (5.0.16–24).

- [x] Schoolbell 5.0.22: проверена загрузка через браузер/LuCI после исправления передачи CSRF через CGI; исходная ошибка сохранена, список перечитывается без повтора POST. Прямой вызов обработчика не заменяет проверку полного HTTP-маршрута.

- [x] Schoolbell 5.0.24: ограниченные повторы GET резервной копии при конкуренции с чтением медиатеки; без автоматического повтора восстановления POST.

- [x] Schoolbell: проверены скачивание и восстановление через страницу с пользовательским MP3; настройки/расписания/годовой план совпали, автозвонки выключены (5.0.24).

- [x] Schoolbell 5.0.27: устранён ложный отказ clock GET при удержании замка writer; bounded pending/GET без повторения команды, отдельные ошибки хранилища и регрессии.

- [x] Schoolbell 5.1.1: последовательный просмотр месяцев календарного диапазона и страницы по 12 месяцев, общий UI Pages/роутера; host-регрессии.

- [x] Школьник 5.1.2: синхронная навигация непосредственно над и под календарём, общая с Pages.
