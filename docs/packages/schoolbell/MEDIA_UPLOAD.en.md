# Melody uploads (engineering profile)

The Melodies tab has six protected bundled slots (test and 0–4) and five user slots (user1–user5). The API rejects bundled replacement and exposes no delete operation. Only user slots accept uploads and replacement. Disable automatic bells first. Existing draft references keep their slot; the next playback uses its new revision. This is not production revision-pinned schedule migration.

Authenticated raw POST uses a CSRF header, an expected generation and a 128-bit random operation ID. Uploads are streamed with a 16 KiB chunk limit. MP3 limits: 512 KiB and 60 seconds. A frame scan and madplay decoding to null precede publication; neither plays sound. Decoder completion does not prove audible quality. The shared player gate excludes replacement, cleanup and activation races. An uncertain decoder outcome retains the gate for administrative recovery; it is never removed based on age alone.

The existing manager stores immutable SHA-256 objects under /etc/modbus-schoolbell/data, atomic current/recovery pointers and one previous snapshot. Original bundled files are untouched. Upload plus retained objects and extra copy must fit 2 MiB and leave max(512 KiB,10% of filesystem capacity), plus metadata allowance. Real free space may impose a smaller limit. Conflicts, truncation, bad audio and failed admission leave the published library unchanged. A lost response can be checked by operation ID; unknown is not rejection. Corruption fails closed, without silently substituting bundled media.

The engineering snapshot contains media overrides only. Full settings/calendar snapshots, backup/import, production FD leases and explicit fallback confirmation remain pending. A crashed request may leave the shared gate; inspect processes and storage before administrative recovery. No automatic power-loss guarantee. The browser preview streams under the same gate; public demo allows only the bundled test sample and no uploads.

Tests: test_mp3.lua, test_media_library.lua, test_media_http.lua, existing 25 manager crash points. Host and router checks do not replace power-loss tests. No core, NTP or network changes.

The storage bar is a statvfs snapshot of the persistent filesystem, not RAM. It also shows the protected free-space reserve and retained user-media bytes against the 2 MiB quota. Refresh the list to update it; free space alone does not guarantee admission.

An empty user slot cannot play; activation rejects enabled rows referencing missing media. Five slots do not waive the total quota/reserve or promise room for five maximum-size files.
