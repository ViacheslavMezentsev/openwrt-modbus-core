# MR3020 v3 console appearance and mode switch

[Русский](README.md) · [Documentation](../../docs/README.en.md)

Owner-provided sources preserved from TL-MR3020 v3.30 running OpenWrt 19.07.9.
These are platform development assets, not a router dump or installable package.
The original MOTD is retained under [legacy](legacy/00-custom-motd.sh). The current
MOTD was updated and installed with owner approval; button/debug sources are unchanged.

## Contents

| Source | Router path and purpose |
| --- | --- |
| [MOTD](files/etc/profile.d/00-custom-motd.sh) | `/etc/profile.d/00-custom-motd.sh`: colored MR3020 ASCII banner, version/kernel, uptime/load, memory/disk/IP, USB/ACM/video/audio and switch position |
| [AP](files/etc/rc.button/mode-ap) | `/etc/rc.button/mode-ap`: writes `ap` on `ACTION=pressed` |
| [3G](files/etc/rc.button/mode-3g) | `/etc/rc.button/mode-3g`: writes `3g` on `ACTION=pressed` |
| [WISP](files/etc/rc.button/mode-wisp) | `/etc/rc.button/mode-wisp`: writes `wisp` on `ACTION=pressed` |
| [Debug](files/etc/hotplug.d/button/00-debug) | `/etc/hotplug.d/button/00-debug`: logs BUTTON/ACTION/SEEN |

The three handlers only write `/tmp/switch_position`; they do not reconfigure
networking. MOTD reads this volatile file or displays `unknown`. These files do
not initialize the position at boot. Their presence does not prove all physical
positions or event delivery after an OS upgrade. The debug hook is preserved
as development work, not a mandatory future package feature.

The source router's `/etc/banner` is a newline. `/etc/profile` prints it and
sources profile.d; PS1 is ordinary. The custom greeting is therefore a MOTD,
not a separate shell implementation. The system profile is not copied and a
future installer must not silently overwrite banner.

## Existing third-party slide-switch

The bench has `slide-switch` 0.9.5-1: `/usr/sbin/slide-switch`, library/data in
`/usr/share/slide-switch/`, the button hotplug `50-slide-switch` and init service
`zzz-slide-switch`. Headers attribute GPLv2 code to
[openwrt-slide-switch](https://github.com/jefferyto/openwrt-slide-switch).
Third-party code is not included here; the custom handlers are not a complete
replacement. No init/update/switch commands were run during preservation.
Review overlapping event processing and file ownership before packaging.

## Current MOTD

Original logo preserved. OS version/model come from the system (v3 is reported;
hardware subrevision 3.30 is not detected automatically). Sections: System,
Network, Peripherals, Applications. Memory uses MemAvailable; space uses overlay.
Core/demo status is labelled reported and includes age: an old file does not
prove a live process. This is a snapshot, not continuous monitoring.

Profile output requires an interactive shell; a subshell isolates all variables
and functions. A MR3020 v3 board_name guard is included. Colors require a TTY
and TERM other than dumb. The shell prints BusyBox; MOTD does not repeat it.
Manual display:

```sh
sh /etc/profile.d/00-custom-motd.sh --show
```

Limits: IP lookup covers br-lan/eth0/eth1; AP counts interfaces rather than proving
Wi-Fi availability; mounts cover /dev/sd*; audio/video count nodes, not devices.
Status directory is fixed at /tmp/modbus; absent fields become unknown. Profile
is not managed until the network package exists. Age uses system time; negative
age is labelled clock mismatch. Repository files are 0644; installed MOTD keeps
its former 0755 mode.

On the OpenWrt 19.07.9 MR3020 bench, syntax, manual display, a real SSH login
(one BusyBox introduction and one MOTD), and silent noninteractive SSH passed.
Verified previous copies are saved on the PC and under router /root outside
profile.d. Cold boot was not tested; networking, services and switch handlers
were unchanged. Roll back by restoring the verified copy through a temporary
file and rename with original permissions; do not source legacy alongside new MOTD.

## Possible separate package

Proposed name: `mr3020-console`, independent of core and applications. Before
implementation agree package-owned documentation/contract: board/version checks,
separate MOTD and switch features, interactive output, dependencies, local edits,
opkg ownership conflicts, install/remove and rollback. Switch behavior needs
startup initialization and coexistence with slide-switch decisions. Installation
must not silently change networking or GPIO modes.

There is no build target, IPK, installer or automatic deployment. MOTD was manually
installed on the approved bench. Physical switch positions were not tested in
this stage; package lifecycle and recovery after reboot remain future work.
