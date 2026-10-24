# Changelog

[Русский](CHANGELOG.md)

## [Unreleased]

- Working schoolbell manual LuCI sound page: browser and router USB audio routes for test.mp3, authentication/POST token and bounded diagnostic process. Both routes and audible sound confirmed by the user on MR3020; automatic scheduling is not integrated.

- Isolated MR3020 checks passed in tmpfs and a separate persistent directory; fixtures removed, no reboot/power loss.

- Schoolbell spec 1.19: isolated prepared-media manager, pointer checksums, fsync/rename, reconciliation and GC; 25 host process-crash checkpoints. No core/queue/sound; MP3 validation and full calendar schemas remain unconnected.

- Schoolbell spec 1.18 accepts strict JSON/SHA-256 revisions, layout, protective MR3020 quotas and current/recovery commit order. TC-83–90 planned; exact metadata fields/crash transitions remain open. Documentation only; no implementation, sound or router changes.

- Schoolbell specification 1.17 accepts persistent media, immutable replacement, consistent bundles and power-loss recovery. Fallback leaves automatic bells paused; TC-73–82 are planned. Requirements only; no implementation, sound or router/IPK changes.

- Exact media revision retention at admission: bounded native catalog, private leases and nine TC-72 host groups. Schoolbell specification 1.16. Mockup settings show separate browser-device and router-speaker test routes; buttons only simulate selection, without sound/API/router changes. IPK unchanged.

- Schoolbell spec 1.15: isolated bridge connects the Lua queue and Linux player; launching/finishing, signal outcomes and cleanup before the next start. Ten fixture-child host groups; no core, audio device, sound or router/IPK changes.

- Schoolbell spec 1.14: isolated Lua 5.1 Linux player binding, userdata and eight host groups with a fixture process, GC/OOM and recoverable handles. No queue/core, audio device, sound or router/IPK changes.

- Saved the accepted standalone schoolbell UI mockup: annual calendar, schedules, media library, player states and system/dark/light themes. Synthetic data only; no API, audio, router changes or IPK inclusion.

- Schoolbell specification 1.13: isolated Linux C player adapter and a test child without an audio device; 13 host process/fault groups, FD checks and inherited flock after owner death. No Lua binding, core, madplay/audio or router changes; IPK unchanged.

- Schoolbell specification 1.12: isolated Lua SBPE codec and player API model with injected operations. 32 host test groups cover frames, generations, deadlines/outcomes, quotas and cleanup. No native binding, processes, sound, core or router changes; IPK unchanged.

- Schoolbell specification 1.11 fixes SBPE/v1 big-endian, generations, attempt counters and parameter ranges. TC-61–65 are planned; requirements only, no code/audio/router changes.

- Schoolbell specification 1.10 defines result/error fields, executable-identity exec evidence, a 16-byte frame and 64/64/8/8 budgets. TC-56–60 are planned; requirements only, code and router unchanged.

- Schoolbell specification 1.9 accepts native player mechanisms and begin/poll/release, inherited flock FD, stdin media, a 2000 ms timeout and /dev/null. TC-50–55 are planned; madplay properties require verification. Code and router unchanged.

- Schoolbell specification 1.8 accepts the system player contract: launching/exit, retained media revisions and blocking after failures. TC-43–49 are planned; implementation, sound, IPK and router are unchanged.

- Schoolbell specification 1.7: isolated Lua playback queue, per-resource FIFO, monotonic TTL/UTC, owner cancellation and an injectable player. 24 host test groups; unknown outcomes retain the resource. No core/process/audio/router integration; media-only IPK unchanged.

- Schoolbell specification 1.6: isolated Lua calendar with fixed/annual modes, quiet dates, midnight preliminary bells and gap/fold rejection. 29 groups, 14,404 independent date vectors and original 15+6 across a full leap year. No core/audio/router integration; media-only IPK unchanged, full parity remains pending.

- Schoolbell specification 1.5 clarifies schema/migration ownership, calendar/media validation and fleet templates versus backups under core 1.16. TC-34/35 are planned; runtime and preview are unchanged.

- Specification 1.4 defines functional parity with the original: two schedule modes, preliminary bells, browser clock synchronization, local UI and five melodies plus test. Added planned TC-14–33, media management and backup. Preview 0.0.1 and runtime are unchanged.

- Specification 1.3 owns audio execution, FIFO/expiry/cancellation transferred from core, with offline dependencies and persistent storage. Manual playback is confirmed; the functional package is not implemented.

- Imported six original MP3s with a manifest; preview IPK 0.0.1 includes only test.mp3 and NOTICE. Specification 1.2 references core 1.7; player/scheduler are not implemented.

- Specification 1.1 references the accepted core 1.6 policy; application requirements and runtime are unchanged.

- Established specification 1.0 with its own requirement/test namespace. Runtime unchanged.
