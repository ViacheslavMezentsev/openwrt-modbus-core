# Schoolbell router page

Schoolbell 5.0.12: persisted router playback attenuation in Settings; takes effect on the next bell while Mute cancels the current one. The system mixer is unchanged.

Automatic bells: independent fixed/annual bell service, explicit saved-plan activation, Mute and no catch-up playback. Reboot/timezone changes require checking the clock and reactivation. System time and NTP are unchanged.

[Русский](README.md)

Open `http://<router>/cgi-bin/luci/admin/schoolbell` using the router's actual
HTTP/HTTPS configuration and normal LuCI login. The page includes the editor, separately activated automatic bells and manual sound tests.

- **Послушать здесь** plays in the current browser/device speakers.
- **Позвонить на роутере** sends an authenticated, CSRF-protected POST to play
  the current test slot through the router USB audio card.
- One button selects system/dark/light theme. Installation does not activate a plan or change the mixer.
  Process exit 0 does not prove audible output.

## Deployment and rollback

This is an engineering payload, not an autonomous IPK. It requires installed
Lua 5.1, LuCI/nixio/luci.jsonc, madplay and working USB audio. No dependency
installation or uhttpd configuration changes are performed.

Back up all existing target paths under `root/`, including modes and hashes;
record absent paths separately and check overlay capacity. Build using
`python3 build-payload.py /tmp/schoolbell-payload.tar`, which includes private
Lua modules, six media files and service scripts (init/sbin 0755, data 0644).
After backup, unpack the payload at the router root, invalidate the LuCI index
and affected module caches, then enable/start only schoolbell-auto. Do not
restart the core or NTP. Before first use of 5.0.10+, explicitly create private `/etc/modbus-schoolbell/data` with mode 0700 and a trusted parent. Preserve it on upgrades; a missing established library needs investigation, not automatic reset. See [media uploads](../../../docs/packages/schoolbell/MEDIA_UPLOAD.en.md). A fresh installation has no active plan.

Rollback first disables automatic bells and waits for playback completion,
then stops/disables schoolbell-auto and restores verified previous payload
files. Remove only files introduced by this payload. Preserve user drafts,
Mute state, common directories and user media.

## Limits and evidence

The diagnostic executor is separate from the production native player, queue
adapter. The media manager is connected through an engineering override layer. HTTP clients cannot supply argv or paths; gain is separately validated. There are
620 waits of 100 ms, followed by SIGKILL of the owned unreaped child and 20
more waits. This is a call budget, not a Linux realtime guarantee.

The `/tmp/schoolbell-sound-test.lock` directory coordinates manual/automatic playback, uploads and the media library.
Unknown outcomes retain the lock: inspect live processes over SSH before
manual recovery. Do not run other players concurrently. Closing the browser
does not stop playback; the short clip may finish. No worker crash recovery.

Host test: `lua5.1 packages/schoolbell/tests/test_sound_test.lua`, included in
`make ci-schoolbell`. MR3020 checks: user-confirmed normal login and both audio
routes, anonymous 403 for page/sample/play, harmless native fixture, real
madplay exit 0. Rejected authorized POST is covered by host tests and LuCI
inspection, not by a separate authenticated invalid-token HTTP test.
The initial page-only experiment used about 20 KiB overlay; that historical figure excludes later features and media and is not the current payload size.
Core/demo and network/USB settings were preserved; no reboot or power-loss test.


## Schedule editor payload

The same page now edits persistent **inactive** schedule drafts.
See [format, API, limits and recovery](../../../docs/packages/schoolbell/SCHEDULE_EDITOR.en.md).
Build the complete payload from the repository root:

```sh
python3 packages/schoolbell/router-page/build-payload.py /tmp/schoolbell-page.tar
```

This includes the sound page/sample and private Lua calendar/JSON/storage dependencies
under /usr/share/schoolbell-editor; it does not replace installed core modules.
Back up all tar target paths with metadata before extraction on the router.
Create /etc/schoolbell-editor with mode 0700 only if absent; never clear existing
drafts during install/update. Invalidate luci-indexcache and the compiled
luci.controller.schoolbell_test module cache after updating the controller.
The earlier root-only copy instructions cover the sound-only subset;
use this complete payload for the editor. Rollback restores code and preserves
/etc/schoolbell-editor drafts; restoring user data is a separate deliberate action.

## Automatic bells (engineering profile 5.0.6)

Check router date/time/timezone, choose the fixed schedule or explicit annual plan, save the draft, then use **Apply saved plan and enable** in Settings. The duty panel shows service confirmation and the next bell **today**. Closing the browser does not stop scheduling. Saving edits does not replace the active snapshot. Disable automatic bells leaves manual playback available; Mute blocks/cancels all schoolbell router audio.

Missing annual dates are quiet and years never repeat implicitly. Coincident event times and DST gaps/folds block that day. Busy playback, Mute, expired events and downtime never create a queue. A durable watermark precedes playback; storage failure prevents admission. Start grace is 2 seconds with a polling gap up to 3 seconds, a skip policy rather than a realtime guarantee.

After reboot or timezone changes, check the router clock and explicitly reactivate. Restarting only the service skips past events. No clock/NTP configuration or correction is performed. This is a procd/Lua/nixio engineering installation using fixed test/0–4 files and the installed madplay, not an autonomous dependency-complete IPK or production core/native-player integration. A short child can finish after parent failure; the shared lock remains for diagnosis. Do not remove it without checking processes. Power-loss and year-long autonomy are unverified.

The separate `/etc/schoolbell-editor/automatic.json` contains the checksummed active snapshot, generation, boot/TZ and watermark. Flash writes occur on control changes, active-service startup, clock/polling gaps and considered event instants; periodic status uses `/tmp`. Journal bounds remain 16 KiB / 24 KiB during publication. Rollback stops/disables only schoolbell-auto, verifies player completion and restores the backed-up payload, retaining the user's draft and Mute settings.

Volume: Settings → Router speaker volume → Apply volume. Presets are −36/−24/−12/−6/0 dB. Volume is saved independently of the draft and activation and applies at the next start, without changing the mixer or browser audio. Use Mute to stop current playback. Legacy state without volume_db means0dB; rollback to5.0.6 ignores attenuation, so disable automatic bells first.

The bench check confirmed annual assignment, Mute cancellation and no catch-up playback; the user confirmed quiet sound. Automation was disabled afterwards and the plan retained. This single check does not guarantee cancellation latency.

After a payload update clear the schoolbell bytecode cache: `ssh openwrt sh -s < packages/schoolbell/router-page/invalidate-cache.sh`. No network/NTP/uhttpd restart is required.
