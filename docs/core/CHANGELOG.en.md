# Changelog

[Русский](CHANGELOG.md)

## [Unreleased]

- Specification 1.10 accepts the local event v1 profile and adds configurable safe-read retries, IPC servicing during waits and compatible read batching. TC-61–71 are planned; runtime unchanged.

- Specification 1.9 extends the public event API, common scheduler and system-time plan. TC-56–60 are planned; transport, quotas and clock-correction policy remain open. Runtime unchanged.

- Corrected core/client ownership: audio moves to schoolbell with historical references. Specification 1.8 defines public events and offline extension admission, storage/upload/recovery/reboot checks; implementation and numerical reserves remain open.

- Accepted atomic registration/snapshot, pending cancellation and monotonic TTL with a UTC deadline; specification 1.7, TC-43–46 remain planned.

- Accepted target unload, audio FIFO/expiry and callback disable/reload policy; specification 1.6 and planned TC-39–42. General implementation is still absent.

- Established specification 1.5 with its own requirement/test namespace. Runtime unchanged.
