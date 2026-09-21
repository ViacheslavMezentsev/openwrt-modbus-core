# Changelog

## core-demo-integration-stage-5-2026-09-22

- Added bounded two-segment event-log rotation with persistent event sequence numbers.
- Updated `modbus-demo` to consume rotated and active event segments by sequence number.
- Added UCI configuration for the event-log segment size and diagnostics showing the last processed sequence.
- Added a bounded router integration test that verifies core-to-demo event delivery and clears the `opkg` cache.
- Confirmed on the MR3020 v3 that event-log rotation, demo CGI delivery and package-cache cleanup work together.

## validation-stage-4-2026-09-08

- Added a single `make all` command for build, local tests, package validation and SHA-256 checksums.
- Added syntax and metadata checks for shell, Lua and package-control files when the respective local tools are available.
- Extended package validation to inspect the control and data payloads of both `.ipk` artifacts.
- Expanded the Lua smoke tests to cover register normalization, JSON escaping and event recording.
- Updated GitHub Actions to run the complete validation path and publish checksums with the packages.

## foundation-2026-05-04

- Created the initial `modbus-rtu-core` package layout for OpenWrt 19.07.9 on MR3020 v3.
- Added a lightweight `.ipk` build flow based on `tar` and `ar`, without the OpenWrt SDK.
- Added WSL-to-router deployment scripts aligned with the current Ansible SSH settings.
- Added the base runtime daemon, UCI config, `procd` init script, cache/event scaffolding and status CGI page.
- Added lightweight verification helpers and router-side `opkg` cache cleanup tooling.
- Removed currently unnecessary audio/video packages from the router to free overlay space while keeping `kmod-usb-acm` and switch handling intact.

## pkg-demo-2026-05-04

- Added the first demo subscriber package `modbus-demo`.
- Added module init scripts, package metadata and lightweight install/remove hooks.
- Added a Lua worker that consumes core event log entries and publishes module status into `/tmp/modbus/demo-status.json`.
- Added demo CGI and a simple diagnostics web page served by `uhttpd`.
- Extended the local build and verify flow to include the demo package.
- Deployed and validated the module on the router end-to-end against live `modbusd` heartbeat events.

## opkg-lifecycle-2026-05-05

- Switched package assembly to an `opkg`-compatible `.ipk` layout for OpenWrt 19.07.
- Added router-side `.ipk` installation tooling for `modbus-rtu-core` and `modbus-demo`.
- Added an `opkg` lifecycle test script covering install, validation, cleanup and reinstall flow.
- Confirmed on-router installation through `opkg install` with both packages registered in the package database.
- Confirmed package-managed startup of `modbusd` and `modbus-demo` after installation.
- Confirmed live status delivery from the demo module after package installation.
