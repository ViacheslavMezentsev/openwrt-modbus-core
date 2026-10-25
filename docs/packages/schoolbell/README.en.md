# Schoolbell package

Schoolbell 5.0.14: persisted router playback attenuation in Settings; takes effect on the next bell while Mute cancels the current one. The system mixer is unchanged.

Automatic bells: independent fixed/annual bell service, explicit saved-plan activation, Mute and no catch-up playback. Reboot/timezone changes require checking the clock and reactivation. System time and NTP are unchanged.



[Русский](README.md)

School calendar, bells and melodies. Calendar calculation, the LuCI editor and an engineering automatic executor are implemented. Public core registration and the production player remain separate stages.

[ТЗ 1.29](TECHNICAL_SPECIFICATION.md) · [CHANGELOG](CHANGELOG.en.md)

The specification remains a draft. Requirement/test IDs belong to this component;
qualify references with `core`, `demo` or `schoolbell`. A specification revision
is not an API version. The root changelog retains pre-split history; future
component changes belong here and in its specification. Research remains local.

## Sample preview package

`make build-schoolbell` creates `out/modbus-schoolbell_0.0.1_all.ipk`;
its independent version is set with `SCHOOLBELL_VERSION`. It is part of `make all`.
This is a media-only preview containing `/usr/share/modbus-schoolbell/melodies/test.mp3`
and NOTICE, with no service, cron, player, configuration, or automatic sound.
The functional port will declare its future core API dependency; no compatibility
with that API is claimed now.

[Original media](../../../packages/schoolbell/media/README.en.md): six MP3s;
only the shortest test.mp3 (about 3.28 s, 13104 bytes) is bundled. CI verifies
the manifest and exact IPK payload using Python 3.8+ on the build host.
The preview package has not been installed. The owner confirmed manual MP3
playback with madplay; this does not validate the functional package.

For the first experiment, connect speakers at minimum volume, then inspect
player availability, the audio device and USB power. After separate agreement,
play the short file once and remove temporary files. Building the IPK does not
install a player, alter mixer/drivers, or produce sound.

Specification 1.3 owns audio execution, FIFO/expiry/cancellation transferred from core, with offline dependencies and persistent storage. Manual playback is confirmed; the functional package is not implemented.

Specification 1.4 defines functional parity with the original: two schedule modes, preliminary bells, browser clock synchronization, local UI and five melodies plus test. Added planned TC-14–33, media management and backup. Preview 0.0.1 and runtime are unchanged.

The separate schoolbell CI job runs for package or dependency changes; locally use `make ci-schoolbell`. See [CI](../../CI.en.md). Hardware acceptance remains separate.

Schoolbell specification 1.5 clarifies schema/migration ownership, calendar/media validation and fleet templates versus backups under core 1.16. TC-34/35 are planned; runtime and preview are unchanged.

Specification 1.6: isolated Lua calendar with fixed/annual modes, quiet dates, midnight preliminary bells and gap/fold rejection. 29 groups, 14,404 independent date vectors and original 15+6 across a full leap year. No core/audio/router integration; media-only IPK unchanged, full parity remains pending.

[Calendar API](CALENDAR.en.md) · `make test-schoolbell`

Schoolbell specification 1.7: isolated Lua playback queue, per-resource FIFO, monotonic TTL/UTC, owner cancellation and an injectable player. 24 host test groups; unknown outcomes retain the resource. No core/process/audio/router integration; media-only IPK unchanged.

[Playback queue](PLAYBACK_QUEUE.en.md) · `make test-schoolbell`

Schoolbell specification 1.8 accepts the system player contract: launching/exit, retained media revisions and blocking after failures. TC-43–49 are planned; implementation, sound, IPK and router are unchanged. [Player adapter](PLAYER_ADAPTER.en.md).

Schoolbell specification 1.9 accepts native player mechanisms and begin/poll/release, inherited flock FD, stdin media, a 2000 ms timeout and /dev/null. TC-50–55 are planned; madplay properties require verification. Code and router unchanged. [System API](PLAYER_SYSTEM_API.en.md).

Schoolbell specification 1.10 defines result/error fields, executable-identity exec evidence, a 16-byte frame and 64/64/8/8 budgets. TC-56–60 are planned; requirements only, code and router unchanged. [Results API](PLAYER_RESULTS.en.md).

Schoolbell specification 1.11 fixes SBPE/v1 big-endian, generations, attempt counters and parameter ranges. TC-61–65 are planned; requirements only, no code/audio/router changes. [Wire contract](PLAYER_WIRE.en.md).

Schoolbell specification 1.12: isolated Lua SBPE codec and player API model with injected operations. 32 host test groups cover frames, generations, deadlines/outcomes, quotas and cleanup. No native binding, processes, sound, core or router changes; IPK unchanged. [Player model](PLAYER_MODEL.en.md).

Schoolbell specification 1.13: isolated Linux C player adapter and a test child without an audio device; 13 host process/fault groups, FD checks and inherited flock after owner death. No Lua binding, core, madplay/audio or router changes; IPK unchanged. [Linux player](LINUX_PLAYER.en.md).

## Accepted interface mockup

[Local UI mockup](../../../packages/schoolbell/ui-mockup/README.en.md): calendar, schedules, media library, states and three theme modes. Synthetic data only; functional UI and integration remain future work. Not included in the IPK.

Schoolbell spec 1.14: isolated Lua 5.1 Linux player binding, userdata and eight host groups with a fixture process, GC/OOM and recoverable handles. No queue/core, audio device, sound or router/IPK changes. [Lua binding](LUA_PLAYER.en.md).

Schoolbell spec 1.15: isolated bridge connects the Lua queue and Linux player; launching/finishing, signal outcomes and cleanup before the next start. Ten fixture-child host groups; no core, audio device, sound or router/IPK changes. [Queue/Linux bridge](QUEUE_LINUX.en.md).

Isolated [admission-time revision retention](MEDIA_ADMISSION.en.md): TC-72, nine host groups. Specification 1.16.

[Persistent media library: accepted requirements](MEDIA_PERSISTENCE.en.md). TC-73–82: planned, not implemented.

[Format, quotas and commit](MEDIA_FORMAT.en.md): accepted 1.18 contract, not implemented.

[Isolated media manager](MEDIA_MANAGER.en.md): prepared objects, no production integration.

- [Schoolbell manual sound check page](../../../packages/schoolbell/router-page/README.en.md).

- [Saved schedule editor](SCHEDULE_EDITOR.en.md).

- [Annual calendar](ANNUAL_CALENDAR.en.md).

The Feedback tab links to [Issues](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/issues) and bug/feature forms, available after the templates reach main. Internet and a GitHub account are required; logs are submitted manually after removing secrets.

[Melody uploads](MEDIA_UPLOAD.en.md).

[Backup and transfer](BACKUP.en.md): restore leaves automatic ringing disabled.

[Clock trust and rollback](CLOCK_TRUST.en.md): accepted requirements, implementation pending.

Specification 1.32 defines the reference format and observation budgets; isolated implementation is pending.

[Isolated clock trust model](CLOCK_TRUST_MODEL.en.md): codec, fake clock/storage and host tests; no executor integration.
