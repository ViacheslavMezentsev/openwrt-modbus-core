# Completed stages

[Русский](completed-stages.md) · [Remaining work](../../TODO.md)

Summary as of 2026-10-09, main `98ad0ea`. See [CHANGELOG](../../CHANGELOG.en.md)
for change history; this is not a new hardware validation run.

- Core/demo foundations: UCI/procd, libraries, cache, CGI, opkg hooks, SDK-free IPKs and CI artifacts.
- Signed commits through Windows Git and the owner-operated push → CI → land workflow.
- BluePill map v2 USB CDC polling, valid/online state and recovery; topics/echo/hz CLI.
- WeAct button/LED control via trusted Lua handlers, event counters and FC05 readback.
- Traceable Russian specification; revision 1.4 remains a draft with explicit open questions.
- Local TTL, incompatible map, readback, handler isolation and limit regressions.
- JSONL entry bounds, pre-rotation oversized rejection, restart/cold-start seq and agreed legacy/lowered-limit behavior.
- Agreed hardware experiments: core restart, USB power cycle with unchanged tty, RESET with USB re-enumeration, router reboot and a two-hour passive run. Limits are in [VALIDATION](../VALIDATION.en.md).
- Demo recovery after detected seq rollback, gap diagnostics, deduplication and bounded read retries; local TC-37/38. The updated demo still needs separately approved installation and hardware measurements.

Release/feed publication, custom runtime, general DO/PWM, RTC and RS-485 are not
completed. TODO is the current list of remaining work.
