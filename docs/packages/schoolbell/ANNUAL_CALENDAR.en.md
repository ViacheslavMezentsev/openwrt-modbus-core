# Annual calendar and preview

[Русский](ANNUAL_CALENDAR.md) · [Editor](SCHEDULE_EDITOR.en.md)

Select a year and schedule, then assign individual dates or a range filtered
to all days, Monday–Friday or weekends. Quiet day removes an assignment;
clearing a year requires confirmation. The grid starts on Monday, underlines
weekends and uses named colors. Narrow screens show one month per row.

Save draft stores schedules and plans as one revision, retaining conflict
protection. Unassigned dates and absent years are quiet; no annual repeat.
Up to eight explicit years share the existing 12 KiB total JSON limit.
Schedules referenced by any assigned date cannot be deleted.

Preview calculates the current browser draft, including unsaved changes,
through the existing Lua calendar. It shows main and preliminary bells,
including the original main-bell date for a preliminary bell across midnight.
Quiet days suppress crossing preliminary bells.

**These are civil wall times, not UTC.** Preview does not validate the router
timezone, DST transitions or readiness for execution. It performs no save,
event registration or playback. Automatic bells remain disabled.

## Format and compatibility

Optional plans contains objects with unique integer year (1–9999),
schedule_ids (up to 16 unique existing schedule IDs), and days.
days is an ASCII string of exactly 365/366 characters starting January 1:
dot means quiet; A–P reference palette positions 1–16.
This avoids repeating long IDs for every date. The server validates all fields
and expands the compact representation into the existing calendar map.
Unknown fields, duplicate years, fractions, invalid codes and dangling references
are rejected. This remains an inactive editor format, not a production snapshot
or import API.

Legacy drafts without plans retain their original bytes/checksum on read; no
migration write occurs. fsync/previous/revision handling is unchanged.
Old code cannot read a newly saved annual draft. Do not silently discard plans
for a downgrade: compare the backup first; restoring old user data is a separate
deliberate action.

Authenticated, CSRF-protected POST preview takes token, draft and date
(YYYY-MM-DD), within existing form limits. The response contains ok,
active=false, clock_basis=civil, date, selected_schedule and events.
Events expose date/time/origin_date/schedule_id/row_id/kind/media; no UTC or
execution promise. The one-day calculation includes next-day preliminary bells.

## Evidence

Twelve host groups cover leap/century years, 0001/9999 boundaries, midnight/year
crossings, quiet days, disabled rows, references and legacy compatibility.
Native crash tests now use full-year data. A local browser with the actual Lua
backend verified assignment, saving, reload and 07:58/08:00 preview.
Target evidence is recorded separately; this is not reboot, power-loss, DST
or automatic execution testing.

The same 12 calendar groups and eight storage interruption points on each filesystem passed on MR3020. Deployed files and preserved user data were verified with SHA256; core/demo and live topics remained healthy. The owner confirmed painting and persistence after reload through LuCI. Target-page preview confirmation remains a separate check.

The primary assignment method is a colored schedule brush: hold the left mouse button and paint dates, or tap dates on touch screens. The quiet-day eraser removes assignments. Range tools are collapsed under Advanced. Save explicitly indicates when there are no changes; requests time out after 15 seconds. A lost save response requires reconciliation and is never retried automatically.

The duty panel shows draft state, preparation mode, no active next bell, the engineering UI revision and installed package versions from opkg. This is not live executor monitoring: no automatic executor is connected. A countdown requires an active plan; absent package metadata is explicit.
