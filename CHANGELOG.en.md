# Changelog

All notable changes to this project are documented here ([Русский](CHANGELOG.md)).
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

- Added separate rover requirements: 2+1/4 bases, browser video overlay, RTU/TCP and watchdog/stop proposals. Specification 1.0 joins docs CI; runtime/router unchanged.

- Lua scheduler accepts a validated profile snapshot: safe FIFO-prefix grouping, lazy fragments, complete-result fan-out and a shared 8 KiB payload reservation pool. 26 host test groups, specification 1.30 / TC-133. No modbusd, native I/O or router changes; total Lua memory budget remains unmeasured.

- Isolated Lua scheduler: FIFO, fixed RTU rounds, independent TCP, enqueue deadlines, coalescing and pass quotas; 19 host test groups. Specification 1.29 / TC-132. No read grouping, real IPC/backend, modbusd or router changes.

- Isolated Lua 5.1 RTU/TCP states with injected clock/byte I/O; deadlines, resync, retries, generations and write outcomes covered by 30 test groups. Specification 1.28. Module ships in IPK; native backend, scheduler and modbusd remain disconnected.

- Accepted isolated c68dec5 reader/loader target verification on OpenWrt 19.07.9/MIPS: 52 Lua groups, native replacements and FD stability. Specification 1.27 records coverage and remaining limits. Documentation only; runtime/installed core unchanged.

- Linux/nixio profile reader: trusted directory/permission/descriptor checks, no-follow, bounds and cleanup. 13 fault groups and native WSL file/race/FD tests; specification 1.26. No modbusd/router changes; package provenance and installer coordination remain.

- Added isolated Lua profile loading: strict schema, limits, shared maps and atomic publication; 19 test groups, specification 1.25. Reader is injected; production filesystem checks and modbusd integration remain.

- Bundled strict Lua 5.1 JSON decoding without LuCI: bounds, Unicode, duplicate keys, types/null and 20 test groups. Explicit decode_strict; legacy consumers preserved. Specification 1.24; Lua loader and hardware RAM measurements remain.

- Accepted JSON device profiles and assembly limits. Added a strict host loader, atomic publication of validated configuration, lazy fragments and an 8 KiB payload reservation pool; 21 new tests. Specification 1.23. Lua/backend, total RAM budgeting and router profile installation remain separate work.

- Accepted safe read maps and grouping rules. The host model groups a compatible FIFO prefix, fans results out and assembles split reads without partial success; 20 new tests. Writes/readback are barriers; writes are never grouped. Specification 1.22; no modbusd or hardware changes.

- Composed RTU/TCP states with FIFO, an RTU barrier, independent TCP, enqueue-time deadlines, periodic coalescing and per-pass quotas. Added 15 host tests; specification 1.21 records partial TC-117–119 coverage. IPC uses synthetic work units; grouping, real drivers and router are unchanged.

- Accepted transport contract 1.19. Added a host-only RTU/TCP state model and 37 controlled-clock/byte tests: deadlines, partial I/O, retries, resync, MBAP/CRC, connection generations and write outcomes. Specification 1.20 records partial TC-111–115/120/121 coverage. No runtime, round queue or hardware changes.

- Specification 1.19 proposes the RTU/TCP contract: operation/attempt deadlines, late responses, safe retries, UCI, quotas and round criteria. New policies and numbers await agreement; TC-111–122 are planned, runtime and router unchanged.

- Specification 1.18 defines minimal package.json, generated bundle metadata and content/compatibility/trust/resource admission. Declarative installation excludes arbitrary extension hooks; trusted IPKs and runtime permissions need separate policies. TC-104–110 are planned; no implementation.

- Specification 1.17 simplifies settings: package.json describes the extension, settings.json contains values only, with separate schema/internal metadata. Accepted load/prepareImport/save/export semantics with an opaque token; TC-101–103 are planned, no implementation.

- Core specification 1.16 accepts shared settings persistence/import, package-owned schemas/migrations and separate fleet templates/backups. TC-93–100 are planned; API, limits and recovery protocol remain open before implementation.

- Specification 1.15 accepts logical devices, autonomous gateways/routes/roles, a Modbus TCP client and the standard offline RNDIS bundle. Implementation is absent; TC-84–92 are planned. Package settings and fleet templates are a separate proposal pending agreement.

- Added an isolated host rounds model and 16 deterministic tests: barrier, early results, timeouts, independent ports, simulated event servicing and a sequential baseline. Checks run in make all/ci-core. Specification 1.14 records partial coverage; the model is not packaged in IPKs or connected to modbusd.

- Core specification 1.13 records accepted multiport rounds: independent port states, a shared barrier, ready-response and event servicing during waits, and single-port compatibility. TC-74–83 are planned; transport and firmware are unchanged.

- Split CI into docs/core/demo/schoolbell with change selection and mandatory ci-gate. Added a pinned specification validator, local link checks, selection/gate regressions and separate package builds; make all retains full coverage.

- Added an isolated Lua event/subscription registry: sessions, atomic replacement, generations, namespace checks and independent snapshots, with 17 tests in make all. Specification 1.11 records partial coverage. The module is not wired into modbusd; public IPC is not operational yet.

- Specification 1.10 accepts the local event v1 profile and adds configurable safe-read retries, IPC servicing during waits and compatible read batching. TC-61–71 are planned; runtime unchanged.

- Promoted the core/schoolbell development sequence to TODO; core specification 1.9 and schoolbell 1.4 define common API boundaries and bell feature parity. New scenarios remain planned; runtime unchanged.

### Added

- Preserved custom MR3020 v3 MOTD and mode/debug handlers with RU/EN limitations and third-party slide-switch boundaries. Contents unchanged; no deployment or new package release.

- Added source-based RU/EN MR3020 v3.30 boot/recovery guides and a Windows SHA-256 recovery staging helper. Networking/flashing are not automated; hardware validation and OEM conversion have not been performed.

- Legacy journal and lowered-limit regressions; agreed deferred rotation and old-history loss documented in specification draft 1.3 without runtime changes.

- Regressions for persisted sequence recovery and cursor rollback on a fresh runtime; bounded hardware validation results and upgrade/rollback guidance.
- Local regressions for TTL, map rejection, readback errors, snapshot/handler isolation, Lua limits and journal byte boundaries; included in normal and isolated router runners.
- Russian technical specification draft 1.0 for core/demo and WeAct map v2, including requirements, test cases, traceability and open resilience questions.
- Project-specific development rules and a technical-specification workflow with stable requirement IDs, test cases and traceability.
- Local-only research conventions and Git exclusions for research/manual workspaces.

### Changed

- MR3020 MOTD retains its original logo with system/network/peripheral/application sections, interactive/board guards, shell isolation and manual --show. Original retained under legacy. Approved bench installation and SSH checks passed; reboot was not tested.

- Split specifications by owner: core 1.5, demo and schoolbell 1.0, with independent README/changelogs and test namespaces. Preserved requirement migration traceability; runtime unchanged.

- Organized documentation with an index and completed-stage archive; remaining early-plan proposals moved to TODO. Original untracked notes are retained in a local archive without publication.

- Specification updated to draft 1.2 without runtime changes; bench observations remain distinct from guarantees.
- Updated the specification to draft 1.1 with actual test coverage and the agreed oversized-entry policy.
- Updated the workflow to reflect signed commits through Windows Git and `git land` in WSL; the owner still verifies CI before landing.
- Push and land belong to the owner; branch CI runs before land without requiring PRs.
- Added paired RU/EN changelogs and refreshed README for core 0.4.0 and WeAct map v2.

### Fixed

- Demo recovers after detected sequence rollback, deduplicates snapshots, reports gaps and defers unstable journal reads after three attempts; startup without state still begins at the tail.

- Oversized JSONL entries fail explicitly before rotation, preserving the active journal, archive, seq and topic registry.
- The local cache test now uses a unique temporary directory with cleanup instead of a shared persistent path.

## Historical Stages

These notes describe earlier work and tests, not checks repeated in this update.
Stage labels are retained, not converted into invented releases or dates.
Later stages supersede earlier limitations. Package version 0.4.0 does not
imply a published Git tag or release.

### lua-button-events-stage-10

- Added opt-in map-v2 system polling at 200 ms using one persistent serial owner; general I/O retains its 5-second interval.
- Added trusted Lua handlers with topic snapshots, a LED-only command allowlist, an eight-command queue and instruction limits.
- Added change-only button/LED topics, command results and handler errors; retained the bounded two-segment journal.
- Button-to-LED example uses counter parity, no replay on startup/reconnect/reset, absolute coil writes and readback.
- Tested counter wrap, bursts, stale snapshots, lost acknowledgements, handler errors/infinite loops and queue limits.
- Installed core 0.4.0 on the router; core/demo and topic CLI regression checks passed. Eleven physical button events produced eleven successful alternating LED commands, with no repeats during two-second holds.
- Restart established count 11 as the new baseline without sending a command. Temporary IPK and opkg list cache were cleaned.


### bluepill-cli-stage-9

- Added a two-job Arduino CLI build for STM32 core 3.0.0 and modbus-esp8266 4.1.0.
- Validate the Maple DFU vector address (0x08002000) and 56 KiB image budget.
- Corrected Arduino pin-number types for compilation with the official STM32 core.
- Retained the user-created Arduino sketch directory.
- Added WeAct v1.1 map v2: reserved PA0 button/PB2 LED, debounced press counter and uptime snapshot; moved AI0 to PA2.
- Added bounded FC05 coil writes with exact echo validation; no automatic button-to-LED logic in firmware.
- Built and flashed the 32216-byte application through router Maple DFU alt 2; CDC returned automatically.
- Passed debounce/wrap tests, RTU validation, hardware identity/LED readback/duplicate-write/invalid-address tests, and existing core/demo integration.
- The new write modules were tested from isolated router /tmp storage; installed core remains read-only until the event-handler stage. Physical button presses still need an end-to-end test.

### topic-cli-stage-8

- Added `modbus topics`, `echo` and `hz` with bounded count/duration options.
- Register heartbeat, sample and transition-status topics in runtime storage.
- Use monotonic publication timestamps, sequence cursors and explicit journal-gap warnings.
- Added rotation, deduplication, lost-message and clock-adjustment regression tests.
- Verified echo count, duration expiry, live frequency and rotation on OpenWrt; `make test-topics-router` reproduces these checks.
- Recorded battery-backed RTC, multi-interface RS-485 gateway and update ideas in TODO.md.

### bluepill-polling-stage-7-2026-09-24

- Added a read-only BluePill profile covering DI, AI, DO and PWM setpoint readback.
- Added bounded nonblocking USB CDC requests with CRC, length and exception validation.
- Publish complete samples to cache and demo events, marking retained data stale on failure.
- Tested CRC rejection, Modbus exceptions, missing unit timeout, recovery and matching live samples in core/demo CGI on MR3020 v3.
- Added `make test-bluepill-router` and explicit IPK version selection during deployment.

### bluepill-modbus-stage-6-2026-09-22

- Added a USB CDC Modbus RTU server sketch for WeAct BluePill STM32F103CB.
- Defined the initial DI, DO, AI and PWM-backed AO prototype register map.
- Added laptop-first STM32duino and ST-Link bring-up instructions for the initial firmware flash.
- Documented the USB CDC boundary and deferred router-side Modbus polling until the board is flashed and verified.

### core-demo-integration-stage-5-2026-09-22

- Added bounded two-segment event-log rotation with persistent event sequence numbers.
- Updated `modbus-demo` to consume rotated and active event segments by sequence number.
- Added UCI configuration for the event-log segment size and diagnostics showing the last processed sequence.
- Added a bounded router integration test that verifies core-to-demo event delivery and clears the `opkg` cache.
- Confirmed on the MR3020 v3 that event-log rotation, demo CGI delivery and package-cache cleanup work together.

### validation-stage-4-2026-09-08

- Added a single `make all` command for build, local tests, package validation and SHA-256 checksums.
- Added syntax and metadata checks for shell, Lua and package-control files when the respective local tools are available.
- Extended package validation to inspect the control and data payloads of both `.ipk` artifacts.
- Expanded the Lua smoke tests to cover register normalization, JSON escaping and event recording.
- Updated GitHub Actions to run the complete validation path and publish checksums with the packages.

### foundation-2026-05-04

- Created the initial `modbus-rtu-core` package layout for OpenWrt 19.07.9 on MR3020 v3.
- Added a lightweight `.ipk` build flow based on `tar` and `ar`, without the OpenWrt SDK.
- Added WSL-to-router deployment scripts aligned with the current Ansible SSH settings.
- Added the base runtime daemon, UCI config, `procd` init script, cache/event scaffolding and status CGI page.
- Added lightweight verification helpers and router-side `opkg` cache cleanup tooling.
- Removed currently unnecessary audio/video packages from the router to free overlay space while keeping `kmod-usb-acm` and switch handling intact.

### pkg-demo-2026-05-04

- Added the first demo subscriber package `modbus-demo`.
- Added module init scripts, package metadata and lightweight install/remove hooks.
- Added a Lua worker that consumes core event log entries and publishes module status into `/tmp/modbus/demo-status.json`.
- Added demo CGI and a simple diagnostics web page served by `uhttpd`.
- Extended the local build and verify flow to include the demo package.
- Deployed and validated the module on the router end-to-end against live `modbusd` heartbeat events.

### opkg-lifecycle-2026-05-05

- Switched package assembly to an `opkg`-compatible `.ipk` layout for OpenWrt 19.07.
- Added router-side `.ipk` installation tooling for `modbus-rtu-core` and `modbus-demo`.
- Added an `opkg` lifecycle test script covering install, validation, cleanup and reinstall flow.
- Confirmed on-router installation through `opkg install` with both packages registered in the package database.
- Confirmed package-managed startup of `modbusd` and `modbus-demo` after installation.
- Confirmed live status delivery from the demo module after package installation.
