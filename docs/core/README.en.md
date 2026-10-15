# Core

[Русский](README.md)

The core owns public events, subscriptions, notifications, common scheduling and Modbus. Application handlers and audio execution belong to client packages. The general API and managed offline installation are not implemented yet.

[ТЗ 1.29](TECHNICAL_SPECIFICATION.md) · [CHANGELOG](CHANGELOG.en.md)

The specification remains a draft. Requirement/test IDs belong to this component;
qualify references with `core`, `demo` or `schoolbell`. A specification revision
is not an API version. The root changelog retains pre-split history; future
component changes belong here and in its specification. Research remains local.

Corrected core/client ownership: audio moves to schoolbell with historical references. Specification 1.8 defines public events and offline extension admission, storage/upload/recovery/reboot checks; implementation and numerical reserves remain open.

Specification 1.9 extends the public event API, common scheduler and system-time plan. TC-56–60 are planned; transport, quotas and clock-correction policy remain open. Runtime unchanged.

Specification 1.10 accepts the local event v1 profile and adds configurable safe-read retries, IPC servicing during waits and compatible read batching. TC-61–71 are planned; runtime unchanged.

[Event API](EVENT_API.en.md)

Added an isolated Lua event/subscription registry: sessions, atomic replacement, generations, namespace checks and independent snapshots, with 17 tests in make all. Specification 1.11 records partial coverage. The module is not wired into modbusd; public IPC is not operational yet.

Core specification 1.13 records accepted multiport rounds: independent port states, a shared barrier, ready-response and event servicing during waits, and single-port compatibility. TC-74–83 are planned; transport and firmware are unchanged.

Added an isolated host rounds model and 16 deterministic tests: barrier, early results, timeouts, independent ports, simulated event servicing and a sequential baseline. Checks run in make all/ci-core. Specification 1.14 records partial coverage; the model is not packaged in IPKs or connected to modbusd.

`python3 scripts/test_rounds_model.py`

Specification 1.15 accepts logical devices, autonomous gateways/routes/roles, a Modbus TCP client and the standard offline RNDIS bundle. Implementation is absent; TC-84–92 are planned. Package settings and fleet templates are a separate proposal pending agreement.

[Architecture](GATEWAY_ARCHITECTURE.en.md)

Core specification 1.16 accepts shared settings persistence/import, package-owned schemas/migrations and separate fleet templates/backups. TC-93–100 are planned; API, limits and recovery protocol remain open before implementation.

Specification 1.17 simplifies settings: package.json describes the extension, settings.json contains values only, with separate schema/internal metadata. Accepted load/prepareImport/save/export semantics with an opaque token; TC-101–103 are planned, no implementation.

[Extension format](EXTENSION_FORMAT.en.md)

Specification 1.18 defines minimal package.json, generated bundle metadata and content/compatibility/trust/resource admission. Declarative installation excludes arbitrary extension hooks; trusted IPKs and runtime permissions need separate policies. TC-104–110 are planned; no implementation.

[Extension admission](EXTENSION_ADMISSION.en.md)

Specification 1.19 proposes the RTU/TCP contract: operation/attempt deadlines, late responses, safe retries, UCI, quotas and round criteria. New policies and numbers await agreement; TC-111–122 are planned, runtime and router unchanged.

[Transport contract](TRANSPORT_CONTRACT.en.md)

Accepted transport contract 1.19. Added a host-only RTU/TCP state model and 37 controlled-clock/byte tests: deadlines, partial I/O, retries, resync, MBAP/CRC, connection generations and write outcomes. Specification 1.20 records partial TC-111–115/120/121 coverage. No runtime, round queue or hardware changes.

[Isolated transport states](TRANSPORT_STATES.en.md)

Composed RTU/TCP states with FIFO, an RTU barrier, independent TCP, enqueue-time deadlines, periodic coalescing and per-pass quotas. Added 15 host tests; specification 1.21 records partial TC-117–119 coverage. IPC uses synthetic work units; grouping, real drivers and router are unchanged.

Accepted safe read maps and grouping rules. The host model groups a compatible FIFO prefix, fans results out and assembles split reads without partial success; 20 new tests. Writes/readback are barriers; writes are never grouped. Specification 1.22; no modbusd or hardware changes.

[Safe read maps and grouping](READ_GROUPING.en.md)

Accepted JSON device profiles and assembly limits. Added a strict host loader, atomic publication of validated configuration, lazy fragments and an 8 KiB payload reservation pool; 21 new tests. Specification 1.23. Lua/backend, total RAM budgeting and router profile installation remain separate work.

[Profile loader and limits](DEVICE_PROFILES.en.md)

[Strict Lua JSON](STRICT_JSON.en.md): bundled decoder and limits.

Lua profile schema/activation is implemented with an injected reader and 19 test groups. The filesystem adapter is implemented in the following stage; modbusd integration remains.

[System profile reader](PROFILE_READER.en.md): Linux/nixio, host tests, no modbusd integration.

Accepted isolated MIPS reader/loader verification (2026-10-15): [conditions and limits](PROFILE_READER.en.md). Installed core unchanged.

Added [isolated Lua RTU/TCP states](TRANSPORT_STATES.en.md): 30 test groups, injected clock and byte events, no modbusd integration.

Isolated Lua scheduler: FIFO, fixed RTU rounds, independent TCP, enqueue deadlines, coalescing and pass quotas; 19 host test groups. Specification 1.29 / TC-132. No read grouping, real IPC/backend, modbusd or router changes.
