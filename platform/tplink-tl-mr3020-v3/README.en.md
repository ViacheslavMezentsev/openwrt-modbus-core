# MR3020 v3 console appearance and mode switch

[Русский](README.md) · [Documentation](../../docs/README.en.md)

Owner-provided sources preserved from TL-MR3020 v3.30 running OpenWrt 19.07.9.
These are platform development assets, not a router dump or installable package.
Selected file contents are unchanged; hashes matched the router during read-only
extraction.

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

## Preserved limitations

- `OpenWrt 19.07.9` is hard-coded and becomes misleading after an upgrade.
- No board check or explicit interactive-terminal guard; sourcing depends on
  profile. Colored output needs testing with SSH automation and other entry paths.
- Memory uses Total−Free rather than Available, including cache.
- Disk reporting uses `/`, not a separate free-overlay measurement.
- USB enumeration needs `lsusb`; a missing utility may appear as zero devices.
- PCM/video/tty node counts are not counts of physical devices.
- IP lookup assumes `br-lan`, then `eth0`.
- Repository source mode is 0644, not installation mode: future packaging must
  assign rc.button 0755 and profile/hotplug modes appropriate to their invocation.

## Possible separate package

Proposed name: `mr3020-console`, independent of core and applications. Before
implementation agree package-owned documentation/contract: board/version checks,
separate MOTD and switch features, interactive output, dependencies, local edits,
opkg ownership conflicts, install/remove and rollback. Switch behavior needs
startup initialization and coexistence with slide-switch decisions. Installation
must not silently change networking or GPIO modes.

There is no build target, IPK, installer or automatic deployment. `sh -n` checks
syntax without execution; matching copies does not validate boot, login or physical
switch positions. The router was not changed. Prepare a separate verified backup
and rollback before any future installation.
