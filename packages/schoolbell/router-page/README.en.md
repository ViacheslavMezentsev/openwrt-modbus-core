# Schoolbell manual sound check

[Русский](README.md)

Open `http://<router>/cgi-bin/luci/admin/schoolbell` using the router's actual
HTTP/HTTPS configuration and normal LuCI login. This commissioning page plays
the bundled short test.mp3; it is not an automatic bell scheduler.

- **Послушать здесь** plays in the current browser/device speakers.
- **Позвонить на роутере** sends an authenticated, CSRF-protected POST to play
  the fixed sample through the router USB audio card.
- One button selects system/dark/light theme. No autoplay or mixer changes.
  Process exit 0 does not prove audible output.

## Deployment and rollback

This is an engineering payload, not an autonomous IPK. It requires installed
Lua 5.1, LuCI/nixio/luci.jsonc, madplay and working USB audio. No dependency
installation or uhttpd configuration changes are performed.

Back up all existing target paths under `root/`, including modes and hashes;
record absent paths separately and check overlay capacity. Copy `root/` to
the router root (directories 0755, files 0644), plus `../media/test.mp3` to
`/usr/share/schoolbell-sound-test/test.mp3` (0644). Expected SHA256:
`1ae57af4d27698b0cd3795de7287c0dd1b5e2b336e8d9e8dcc9b853cbd8b4e0d`.
Invalidate only generated `/tmp/luci-indexcache`; no service restart is needed.

For rollback, confirm playback has ended and deployed files have not changed.
Restore backed-up originals with metadata, remove only newly installed payload
files, then invalidate that index again. Do not remove shared directories,
user settings or unrelated media.

## Limits and evidence

The diagnostic executor is separate from the production native player, queue
and media manager. HTTP clients cannot supply argv, paths or gain. There are
100 waits of 100 ms, followed by SIGKILL of the owned unreaped child and 20
more waits. This is a call budget, not a Linux realtime guarantee.

The `/tmp/schoolbell-sound-test.lock` directory coordinates only this page.
Unknown outcomes retain the lock: inspect live processes over SSH before
manual recovery. Do not run other players concurrently. Closing the browser
does not stop playback; the short clip may finish. No worker crash recovery.

Host test: `lua5.1 packages/schoolbell/tests/test_sound_test.lua`, included in
`make ci-schoolbell`. MR3020 checks: user-confirmed normal login and both audio
routes, anonymous 403 for page/sample/play, harmless native fixture, real
madplay exit 0. Rejected authorized POST is covered by host tests and LuCI
inspection, not by a separate authenticated invalid-token HTTP test.
Observed additional overlay was about 20 KiB, not a universal storage budget.
Core/demo and network/USB settings were preserved; no reboot or power-loss test.
