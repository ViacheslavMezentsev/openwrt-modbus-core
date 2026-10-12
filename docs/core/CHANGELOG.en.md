# Changelog

[Русский](CHANGELOG.md)

## [Unreleased]

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

- Specification 1.9 extends the public event API, common scheduler and system-time plan. TC-56–60 are planned; transport, quotas and clock-correction policy remain open. Runtime unchanged.

- Corrected core/client ownership: audio moves to schoolbell with historical references. Specification 1.8 defines public events and offline extension admission, storage/upload/recovery/reboot checks; implementation and numerical reserves remain open.

- Accepted atomic registration/snapshot, pending cancellation and monotonic TTL with a UTC deadline; specification 1.7, TC-43–46 remain planned.

- Accepted target unload, audio FIFO/expiry and callback disable/reload policy; specification 1.6 and planned TC-39–42. General implementation is still absent.

- Established specification 1.5 with its own requirement/test namespace. Runtime unchanged.
