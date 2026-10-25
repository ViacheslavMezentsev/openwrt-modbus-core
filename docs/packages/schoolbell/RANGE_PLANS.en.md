# Named calendar plans

[Русский](RANGE_PLANS.md)

Stage 5.0.35 provides an interactive Pages prototype at `schoolbell/ranges.html`,
linked from the demo. The live editor, Lua storage, executor and `.sbb` format
remain year-based. The prototype neither persists data nor contacts hardware.

Each plan has a stable ID, editable name and inclusive start/end dates. Multiple
non-overlapping ranges support creation, rename, resize, copy and deletion.
Selecting a plan changes the view, not activation. Painting is the main assignment
method; viewing a date never edits it. Bulk assignment is supplementary.

Resize preserves assignments by actual date, adds quiet dates and confirms removal
of assigned dates. Deleting a plan preserves schedules/media. Prototype copying
uses day offsets and warns that weekdays may differ. There is no annual repeat.

First installation has no plans. New Plan may propose September–May only from a
trusted router date; before September it uses the previous autumn's academic year.
Users can edit the proposal, including choosing next season in summer. Untrusted
clocks leave dates empty for manual input or clock verification. Explicit creation
makes all dates quiet and never enables automatic bells. Prototype date/trust inputs
are labeled synthetic; browser time is not evidence of router trust.

Proposed fields: `{id,name,start,end,schedule_ids,days}`. One character per inclusive
date; `.` is quiet. Provisional bounds retain the existing budget: 8 plans, 16 schedule references per plan, 96 UTF-8 bytes per name. Legacy years map to
January 1–December 31 without assignment changes. Only a pure conversion copy is
tested, not on-device file migration.

Checks: `make check-site`, `scripts/test-schoolbell-ranges.js` (TC-142).
Next: Lua model, persistence/backup migration and execution tests, followed by a
separately backed-up installation.

The owner removed the fixed day-count quota. Live integration must check actual document size and available resources, failing clearly without replacing the previous plan. Dates use YYYY-MM-DD (years 0001–9999). The existing 12288-byte live storage bound is unchanged in this prototype stage; it is not a calendar-duration quota.
