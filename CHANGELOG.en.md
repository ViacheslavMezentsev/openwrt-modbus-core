# Changelog

All notable changes to this project are documented here ([Русский](CHANGELOG.md)).
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- Legacy journal and lowered-limit regressions; agreed deferred rotation and old-history loss documented in specification draft 1.3 without runtime changes.

- Regressions for persisted sequence recovery and cursor rollback on a fresh runtime; bounded hardware validation results and upgrade/rollback guidance.
- Local regressions for TTL, map rejection, readback errors, snapshot/handler isolation, Lua limits and journal byte boundaries; included in normal and isolated router runners.
- Russian technical specification draft 1.0 for core/demo and WeAct map v2, including requirements, test cases, traceability and open resilience questions.
- Project-specific development rules and a technical-specification workflow with stable requirement IDs, test cases and traceability.
- Local-only research conventions and Git exclusions for research/manual workspaces.

### Changed

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
