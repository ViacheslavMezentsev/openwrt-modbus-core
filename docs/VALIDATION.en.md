# Recovery and upgrade validation

[Русский](VALIDATION.md)

## Observed on 2026-10-09

Bench: OpenWrt 19.07.9, MR3020 v3, kernel 4.14.267, Lua 5.1,
BluePill map v2, core `0.4.0-1+gee4dabe`, demo `0.1.0`.
This is a build from `ee4dabe`, not a new release. Configuration and handlers
were checked with SHA-256; raw hardware logs and backups are not published.

| Scenario | Observation | Limitation |
| :--- | :--- | :--- |
| Upgrade, rollback, re-upgrade | Original files restored; new build left running | UCI needed explicit verification/restoration after opkg |
| One core restart | Fresh sample, baseline without commands, demo continued | An observer error left about 47 seconds without resource samples |
| Board USB power cycle | Offline/invalid, ttyACM0 returned, baseline without replay | First attempt affected the hub; isolated repeat did not affect hub/audio. Changed tty name untested |
| One MCU RESET | Recovery with a new baseline | USB re-enumerated; reset without transport loss untested |
| One router reboot | Core/demo autostart, fresh RAM runtime with seq=1, fresh data | Does not test power loss during writes or Flash corruption |
| Two passive hours, 30-second sampling | 241 snapshots, 1864 events without gaps, no restarts/new commands; core RSS 1404→1408 KiB, demo 1044 KiB; segments <=65536 bytes | No guarantee against leaks/peaks; CPU/RAM limits still undecided |

`make test-bluepill-router` and `make test-topics-router` passed after scenarios.
Hardware scenarios were not repeated while promoting these results.
A recovery time from one experiment is not a normative deadline.
Audio playback was not tested; USB enumeration does not validate the audio path.

## Automated regressions

With Lua 5.1, `make all` runs `scripts/test_events.lua` and
`scripts/test_topics.lua`: a new writer instance continues persisted seq,
a fresh runtime starts at 1, and CLI following an empty interval detects lower
seq and delivers the new sequence without replay. Tests use isolated temporary
directories and do not reboot devices. They do not establish file atomicity
under power loss or cover every demo sequence discontinuity.

## Upgrade and rollback

Before installation, capture actual installed core files, UCI, custom
handlers/triggers, conffiles, package hooks/opkg metadata and autostart state.
Verify extraction and backup hashes; compare the rollback IPK with original
files. Do not replace the global opkg database or network configuration for
a core-only rollback.

Distinguish builds by revision-bearing version and payload/IPK SHA-256; `0.4.0`
alone is insufficient. Build only core with `make build-core VERSION=<build-version>`;
do not use a two-package installer to update one package.

Conffiles do not provide unconditional protection. When a reconstructed rollback
package embeds current user UCI as its packaged default, the next upgrade may
consider it unmodified and replace it. Compare configuration after installation;
if replaced, stop core, restore the working copy, verify hashes and start core.
Then check fresh core/demo data, topics and serial ownership, and remove only
this installation's temporary files. Retain backups locally. Rollback is a
recovery path, not the final step of a successful upgrade.

## Observation rules

- `meta.started_at` is loaded from cache. Identify a process by PID and
  `/proc/PID/stat` starttime, and a router boot by boot ID.
- Time/file reads are not atomic. Record start/end timestamps; an update between
  reads can produce an apparent age of -1 second. Preserve and investigate the
  original flag without masking real clock jumps.
- Read both journal segments and check seq; distinguish observer gaps from
  absent events. Seq is not a global ID across reboots.
- System topic age measures publication changes, not every USB poll.
- Each new reboot, USB disconnect/reset and soak needs separate agreement.
  Core remains the sole serial owner; open specification questions remain open.
