# Core

[Русский](README.md)

The core owns public events, subscriptions, notifications, common scheduling and Modbus. Application handlers and audio execution belong to client packages. The general API and managed offline installation are not implemented yet.

[ТЗ 1.10](TECHNICAL_SPECIFICATION.md) · [CHANGELOG](CHANGELOG.en.md)

The specification remains a draft. Requirement/test IDs belong to this component;
qualify references with `core`, `demo` or `schoolbell`. A specification revision
is not an API version. The root changelog retains pre-split history; future
component changes belong here and in its specification. Research remains local.

Corrected core/client ownership: audio moves to schoolbell with historical references. Specification 1.8 defines public events and offline extension admission, storage/upload/recovery/reboot checks; implementation and numerical reserves remain open.

Specification 1.9 extends the public event API, common scheduler and system-time plan. TC-56–60 are planned; transport, quotas and clock-correction policy remain open. Runtime unchanged.

Specification 1.10 accepts the local event v1 profile and adds configurable safe-read retries, IPC servicing during waits and compatible read batching. TC-61–71 are planned; runtime unchanged.

[Event API](EVENT_API.en.md)
