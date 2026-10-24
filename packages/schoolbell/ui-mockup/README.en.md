# Schoolbell UI mockup

[Русский](README.md) · [Package](../../../docs/packages/schoolbell/README.en.md)

Accepted visual sketch with synthetic data. Open [index.html](index.html)
directly from the filesystem in a browser. No build, server, Internet or
external libraries are required. Optional host HTTP preview:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory packages/schoolbell/ui-mockup
# Open http://127.0.0.1:8765; stop the server with Ctrl+C.
```

## Available interactions

- Twelve-month calendar: select a date and assign a normal/short/exam schedule
  or a quiet day. The initial 2027 plan is empty.
- Three sample schedules: edit times and select melodies, then save in tab
  memory only. Times must be in ascending order.
- Media library: sample cards without file upload or playback.
- Player: manually select five simulated states, including uncertain completion
  with the resource held.
- One header theme button: system → dark → light. localStorage remembers the
  selection when permitted; without storage the button still works for the
  current page. System mode follows the OS preference.

## Limits

All data is synthetic. The next-bell summary, clock, history and progress are
fixed examples, not measurements. Plan/schedule edits reset on reload; unsaved
form edits are lost when another template is selected. Theme preference is
stored separately from this temporary data.

There is no API, core, process, audio, router networking, upload, import/export,
plan publication, row operations or hardware control. The mockup is not in the
IPK. Its simplified preliminary-bell calculation does not replace the Lua
calendar: time zones, clock transitions and midnight are not fully handled.
The test.mp3 and sample melody names do not open actual files.

This is a P07 sketch, not implementation or acceptance of TC-19–21/25–29 in the
[package specification](../../../docs/packages/schoolbell/TECHNICAL_SPECIFICATION.md).
The functional UI, authorization, shared preview calculator, editing conflicts
and persistent storage remain in TODO. Responsive CSS is provided; physical
tablet testing has not been performed.

## Manual check

Visit all four sections; select 2027 and check that the plan is empty.
Assign a schedule to a date, then a quiet day: its events disappear.
Edit a time, save in the mockup and inspect a date using that template.
Switch player states and all three theme modes; reload: the plan resets,
while theme preference persists if localStorage is available.
These checks do not validate a real player or installed package.

Sources: index.html, style.css, app.js, theme.css, theme.js. Screenshots,
browser logs and a duplicate HTML with embedded assets are not stored here.
