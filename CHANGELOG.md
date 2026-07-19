# Changelog

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
