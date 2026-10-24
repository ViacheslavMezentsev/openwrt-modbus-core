# Saved schedule editor

[Русский](SCHEDULE_EDITOR.md) · [Page and deployment](../../../packages/schoolbell/router-page/README.en.md)

Open `/cgi-bin/luci/admin/schoolbell` with normal LuCI login. Create a named
schedule, edit rows and explicitly save the draft to the router. Reload reads
router storage, not localStorage. Switching schedules retains unsaved changes;
leaving the page warns about them. Create/copy/delete schedules and clear rows
affect only the browser draft until saved.

**Saving or enabling a row never starts automatic bells.** Dates are not assigned.
The existing manual audio buttons remain separate actions and are not invoked
by the editor.

## Values and limits

Up to 16 schedules, 32 rows each and 128 total; canonical JSON <=12288 bytes.
All limits apply together: the row count does not guarantee the byte limit.
Names contain 1–96 UTF-8 bytes, no control characters, and cannot be whitespace-only.
Rows use unique local `id`, strict HH:MM `time`, `media`, and boolean
`enabled/pre`. Preliminary interval is 1–10 minutes. Only media ID `test`
is currently available. Strict JSON and the existing calendar validator reject
unknown fields, duplicate keys/IDs, wrong types and invalid times.

The data object has `schedules: [{id, name, rows: [{id, time, media, enabled, pre}]}]`,
`pre_minutes` and `pre_media`. No extra version fields are added to user values.
This editor draft schema is not the complete import/backup or active snapshot contract.

## Save and conflicts

Authenticated GET `schedules` returns `ok, revision, data, active=false`;
initial revision is `empty`. POST `save-schedules` accepts URL-encoded
`token, revision, draft`. The form is bounded to 49152 bytes before decoding,
the draft to 12288. LuCI authentication and CSRF apply; clients cannot supply paths.

revision is the SHA256 of canonical values, checked under an exclusive lock.
Stale tabs receive conflict without overwriting data. Identical contents do not
rewrite flash. A→B→A has the same hash; this is content comparison, not activation.
Unknown outcomes and conflicts preserve browser edits but disable another save
until reload/reconciliation. Reload over edits requires confirmation. There is
no automatic merge or draft export: preserve desired edits before closing/reloading.

## Persistent storage

Private 0700 directory `/etc/schoolbell-editor` holds service checkpoint
`current.json` with `data/checksum` and the previous complete `previous.json`.
These are not user settings.json files or production media snapshots.

Under the lock: validate the current revision, check space including
max(512 KiB, 10%) reserve, write/fsync next, write/fsync/rename previous,
rename next to current, fsync directory, reread. The peak allows an extra 48 KiB
for two transient files and allocation/metadata. ENOSPC and later I/O failures
are still handled after the space check.

Corrupt current, or missing current with existing previous, blocks writes.
There is no automatic reset/fallback activation; inspect first. Leftover next
files are never promoted by reads. After an uncertain result, reread instead
of blindly replaying the POST. OS process termination releases the file lock.

## Evidence and limitations

14 host groups cover schema, conflicts, no-op, corruption, capacity, write/sync
failures and HTTP guards. Native host tests cover process restart, eight crash
checkpoints, concurrent locking and symlink rejection. The eight interruption
points passed in both /tmp and a separate persistent MR3020 directory; probes
were removed.

This is not power-loss/reboot testing, a complete RAM budget or an autonomous
IPK. Annual plans, production snapshot migration, media references and automatic
scheduling remain future work; full original schoolbell parity stays in TODO.
