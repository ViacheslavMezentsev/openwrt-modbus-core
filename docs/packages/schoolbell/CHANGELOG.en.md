# Changelog

Installed 5.0.27 with native clock1.0.0: real mailbox contention and browser confirmation verified. Control enabled, time confirmed, automatic bells disabled; clocks/NTP unchanged.

5.0.27: clock-result lock contention is pending, not failure; bounded GET waiting, no POST replay. Storage errors are distinct from busy.

5.0.26: native clock dependency and authenticated time confirmation/bypass UI, worker-owned activation, host tests. Not installed. See [time controls](CLOCK_UI.en.md).


5.0.5: lock-free atomic mute snapshots; distinct network/auth/storage errors.

5.0.4: persistent mute, owned-child cancellation, manual/pre-bell media test/0–4, daily or annual preview mode. No automatic bell activation.

5.0.3: fix UCI commit (-p instead of -P for commit only); regression reads the file after closing staging, not just the staged view.
[Русский](CHANGELOG.md)

## [Unreleased]

- 5.0.25: executor clock admission with explicit optional bypass and injected-clock tests. Not deployed. Native dependency and confirmation UI remain deployment prerequisites: [integration scope](CLOCK_EXECUTOR.en.md).


- 5.0.24: backup status and download retry transient busy GETs up to four attempts with 200/500/1000 ms delays. Download retains one overall 180 s deadline. Restore POST is never automatically retried; exhaustion leaves the status check available.


- 5.0.23: title and filename spaces use %20 for LuCI 19.07 CGI; literal plus signs remain plus signs.


- 5.0.22: MP3 upload and restore carry the CSRF token in Authorization: Bearer, forwarded by uhttpd 19.07 CGI. A LuCI session and an exact CSRF token match remain required; tokens never enter URLs. CGI previously dropped X-CSRF-Token, causing HTTP403 before file writes.


- 5.0.21: unconfirmed uploads retain the original error and operation ID; the list is fetched again without resending the file. Failed reads preserve disabled stale rows until refresh. This is a diagnostic fix; the browser upload failure cause remains under investigation.

- 5.0.20: transient media-list busy receives up to four GET attempts with 200/500/1000 ms pauses. Exhaustion preserves the previous list as unconfirmed, disables actions and leaves refresh available. Busy is not called corruption. Upload POST is never retried.

- Schoolbell 5.0.19: fix empty LuCI audio responses on Lua 5.1. Streaming sources/sinks use coroutine-safe protection throughout; regressions cover yielding upload/download and cleanup after disconnect.

- Schoolbell 5.0.18: confirmed uploads automatically refresh the media list. Every populated row has browser playback; empty slots are labeled in the table and selectors and cannot be played. A refresh failure does not reupload the saved file. The demo includes all six bundled melodies. Host checks without sound; not deployed to the router.

- Schoolbell 5.0.17: backup downloads have a 180-second overall deadline, including the response body. Timeout/disconnection returns control; check status before retrying. Late responses are not saved and restoration is never started automatically. Pages displays the UTC build date and commit. Host-tested; not deployed to the router.

- Schoolbell 5.0.16: the calendar starts in view mode; clicking a date previews draft bells without erasing its assignment. Explicitly select a schedule or eraser to paint. A shared panel distinguishes the draft from the active snapshot. Save edits first, then separately apply the checked revision; changes from another window require reloading. Preview is not execution evidence. Validated on the host and in the browser demo; not deployed to the router.

- Schoolbell 5.0.15: storage usage >75% turns yellow, >90% red, with a text warning; shared router/demo styles. Not deployed to the router.

- Specification 1.34: BOOTTIME/REALTIME system ports and bounded FD reference storage, real host operations/fault tests; overlapping rounded observation brackets. No payload/executor/router changes.

- Specification 1.33: isolated UTC-ms reference codec, atomic CAS store and clock trust model; host boundary/fault tests. Version 5.0.14 and payload unchanged.

- Specification 1.32 accepts schoolbell-clock/1, hourly checkpointing and observation/confirmation budgets; TC-120–124 planned. Requirements only; no implementation or package version change.

- Accepted clock-trust and rollback contract (specification 1.31): automatic admission gate, separate time confirmation and enable; TC-113–119 planned. Documentation only, no version/runtime/router changes.

- Schoolbell 5.0.14: fix yielding LuCI backup download/upload; timezone is the first settings section.

- Schoolbell 5.0.13: backup/restore with automatic ringing disabled; eight user melodies with display titles; manual sound checks in the Melodies tab.

- Schoolbell 5.0.12: six protected bundled melodies plus five user slots; missing user media blocks plan activation.

- Schoolbell 5.0.11: persistent-storage usage bar, free space, protected reserve and retained media usage.

- Schoolbell 5.0.10: bounded melody uploads/replacement via the existing media manager, shared player gate, CAS and browser preview; no automatic activation.

- Schoolbell 5.0.9: aligned settings fields and subtle alternating table rows in both themes.

- Fixed in schoolbell 5.0.8: a normal polling delay no longer recursively writes the time watermark; reuse the verified serialized snapshot without repeating SHA before playback.

- Schoolbell 5.0.7: persisted router playback attenuation in Settings; takes effect on the next bell while Mute cancels the current one. The system mixer is unchanged.

- Schoolbell 5.0.6: independent fixed/annual bell service, explicit saved-plan activation, Mute and no catch-up playback. Reboot/timezone changes require checking the clock and reactivation. System time and NTP are unchanged.

- Schoolbell 5.0.2: distinct xterm256 colors with black/white text, an in-module time-zone selector with confirmation and conflict checks; a GitHub Pages landing page and browser-local demo sharing the router UI.

- Feedback tab: instructions and bug/feature form links, version context and a public-data warning.

- Schoolbell 5.0.1: persistent per-schedule colors from 16 muted shades, automatic assignment and manual selection, consistent across the list, calendar and preview. Journal text is left-aligned; time-zone settings are offered independently of clock synchronization.

- Schoolbell 5.0.0: collapsible status, tabs preserving edits, router/browser clocks and a LuCI synchronization link; private rotating journal with up to 16 KiB of records (24 KiB during commit). Automatic bells remain disabled; the UI never changes system time automatically.

- Schoolbell annual calendar: date/range assignments, shared draft persistence and civil-time main/preliminary bell preview. Legacy drafts remain unchanged on read; automatic execution stays disabled. Specification 1.22.

- Schoolbell schedule editor: names, rows, copying, persistent inactive drafts, reload/save, conflict and storage-failure checks. Automatic bells and annual calendar remain disconnected; specification 1.21.

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
