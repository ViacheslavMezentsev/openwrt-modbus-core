# TL-MR3020 v3.30: boot diagnostics and recovery

[Русский](ROUTER_RECOVERY.md) · [Documentation](README.en.md)

Sources checked: 2026-10-12. This is an operations guide, not a change to the core's
supported platform. The owner runs OpenWrt 19.07.9; newer images previously failed
to boot, with no UART diagnosis yet. This procedure has not been revalidated on
v3.30 hardware. Flashing, rebooting and network changes require a separate agreed
hardware session or are performed by the owner.

## 1. Evidence and revision limits

OpenWrt publishes `tplink_tl-mr3020-v3`, target `ramips/mt76x8`, with 8 MiB flash
and 64 MiB RAM. The checked directories have no separate v3.30 profile. TP-Link
publishes a V3.30 page. Do not assume that its bootloader, pinout or OEM image
format is identical to early v3 hardware (S1–S3).

The documented v3 bootloader downloads `tp_recovery.bin` from a PC TFTP server
at `192.168.0.225/24` when powered on with Reset held. S1 describes roughly
6–7 seconds until the request; S2 describes holding for 20–30 seconds through
transfer completion. Observe UART and the actual request, rather than relying
on a timer. Transfer completion does not prove flash completion or OS startup.
Do not interrupt power during flashing.

Before testing v3.30 record the label's hardware revision/region, PCB markings,
bootloader version, requested filename/IP and boot log. Missing evidence must
not be replaced with generic flash erase commands or MR3020 v1 instructions.

## 2. Separate paths

| State | Method | Artifact |
| --- | --- | --- |
| OpenWrt boots | Standard sysupgrade after checks and backup | `*-squashfs-sysupgrade.bin` |
| OS fails, bootloader recovery works | Router downloads from Windows TFTP server | `*-squashfs-tftp-recovery.bin` renamed to `tp_recovery.bin` |
| UART diagnosis | Capture first; RAM boot depends on actual bootloader capabilities | `*-initramfs-kernel.bin`, where available and supported |

Do not rename initramfs to a recovery image: automatic recovery may write it to
flash. RAM boot is not guaranteed to be a menu option; determine commands and
addresses from this bootloader. Do not copy `erase`, `cp`, `sf write`, `mtd write`
or `saveenv` commands from unrelated examples. OpenWrt failsafe requires a working
kernel and is not bootloader recovery.

## 3. Rollback and release selection

Before changing OS, save configuration, handlers, package versions, matching IPKs
and dependencies, rollback images and SHA-256 outside the router. A sysupgrade
configuration backup does not contain installed programs or the entire flash.
Use a new numbered local investigation under `docs/research/NN-router-recovery/`
and `tests/manual/NN-router-recovery/`. Never commit images, dumps, hardware logs,
real MAC/serial identifiers or keys.

Read-only inventory through WSL Ubuntu-20.04:

```sh
ssh openwrt 'ubus call system board; cat /proc/mtd; uname -a; opkg list-installed; df -h'
```

Save output locally. Before backing up flash partitions, inspect this device's
`/proc/mtd`; do not copy old wiki partition numbers. Preserve bootloader and radio
calibration. This guide provides no commands to overwrite either.

Official image candidates (S4): 19.07.9 is the known baseline; 19.07.10 is the
adjacent release; then test 21.02.7, 22.03.7 and 23.05.6 individually. Availability
is not a v3.30 hardware PASS. Older branches are diagnostic comparisons, not a
promise of current security maintenance.

Download the image and `sha256sums` from the same release directory. Verify
model/target, checksum and, where possible, the checksum list's signature. Record
source/date. A locally calculated hash of an unknown file does not establish
provenance. Do not reuse old OS packages/kmods: architecture, ABI and exact kernel
must match the selected release.

Test major-release changes with clean configuration and selectively restore
settings. For standard upgrades, run `sysupgrade -T` on the chosen sysupgrade
image first; do not bypass rejection with `-F`. Actual writing is a separate
approved step with rollback ready, not an automatic command in this guide.

## 4. UART: locate the boot failure

S2 identifies early-v3 TP2=TX and TP1=RX; S3 specifies 3.3 V UART at 115200 8N1.
Verify pads/ground on v3.30 instead of assuming those markings. Use a 3.3 V USB–TTL
adapter, not RS-232 or 5 V. Connect common GND and router TX to adapter RX; leave
adapter TX disconnected for initial logging. Do not connect adapter VCC; power
the router normally. Make wiring connections with power removed.

Open the adapter's COM port at 115200, 8 bits, no parity, one stop bit, no flow
control. Enable full logging before power-on. This is the router's own UART,
not the Modbus board's `/dev/ttyACM0`, which must not be opened alongside the core.

| Last observation | Next investigation |
| --- | --- |
| No characters | Power, GND, RX/TX, voltage, COM and baud; not proof of a damaged bootloader |
| Bootloader rejects image | Format/header/checksum/region and full rejection text |
| Linux starts then panics | Full panic, flash layout, rootfs mount, memory and drivers |
| Repeated reset | Power/watchdog/crash; compare stage and messages without guessing the cause |
| Shell works, network does not | OS boot succeeded; diagnose networking separately |

The diagnostic result is the complete log and last successful stage. Agree RAM
boot or bootloader commands separately before sending them.

## 5. Windows: a server that waits for the router

Use Tftpd64 from its author's repository (S5). The server waits and responds to
the router's request; no ping loop or repeated `tftp put` is needed. Windows
`tftp.exe` is a client, not the required server (S6). Run the server natively on
Windows to avoid forwarding UDP through WSL2 NAT. Project SSH remains in WSL.

1. Use a dedicated Ethernet/USB–Ethernet adapter connected to the router. Keeping
   it reserved for recovery avoids reconfiguring the normal network repeatedly.
2. Record its IPv4, DHCP, DNS, routes and name/index. In IPv4 properties set
   `192.168.0.225`, mask `255.255.255.0`, no gateway or DNS. Check for conflicting
   interfaces/routes in that subnet. Do not disable all adapters or the firewall.
3. In Tftpd64 select `192.168.0.225` under Server interfaces and an isolated Current
   Directory containing only the approved `tp_recovery.bin`. Disable unused
   servers, especially DHCP; restrict access to the directory and read operations.
4. Allow inbound UDP for that executable only on the recovery interface/local
   address, from `192.168.0.0/24`, accounting for the Windows network profile.
   Port 69 alone is insufficient: TFTP uses a separate UDP transfer port.
5. Start the server before powering the router. Start UART logging, hold Reset
   and apply power. Observe request, transfer, flash completion and reboot.
6. Without a request, inspect link, server binding/firewall and UART. Do not try
   random images or treat a failed ping as proof of TFTP failure.
7. Close the server, remove its temporary firewall rule and restore original
   adapter settings unless it is dedicated to recovery. Verify normal network
   access. The booted OS may use a different address than recovery.

An ordinary switch between PC and router may keep the PC link up during router
restarts; this is a diagnostic option for delayed link negotiation, not required
hardware.

### File preparation helper

[prepare-router-recovery.ps1](../scripts/windows/prepare-router-recovery.ps1)
runs in Windows PowerShell 5.1+ without administrator privileges. Stop the TFTP
server before preparation. Fill these variables with operator-selected values:

```powershell
& .\scripts\windows\prepare-router-recovery.ps1 `
    -Image $DownloadedRecoveryImage `
    -ExpectedSha256 $HashFromOfficialChecksums `
    -OutputDirectory $NewEmptyRecoveryDirectory
```

The helper accepts only a named OpenWrt v3 recovery artifact, verifies SHA-256,
creates a new directory and copies it as `tp_recovery.bin`, checking the copy.
It refuses existing directories. Synthetic copy, wrong hash, existing directory
and sysupgrade rejection were tested locally in PowerShell 7; Windows PowerShell
5.1 has not been exercised separately. It does not download/select firmware, identify
the board, change networking, start a server or flash anything. After an interrupted
preparation, do not serve the directory without checking it; retry with a new one.
Select the prepared directory in Tftpd64; that server handles waiting/transmission.

RemoteSigned may require a script signature when running from a WSL UNC path.
Do not change system policy: after reviewing the source, use a local Windows
copy where permitted; Git signatures are not Authenticode signatures. Follow
managed-environment script policies.

Full network automation is a separate future step: preflight, persistent state
snapshot, explicit adapter/image selection, narrow temporary firewall rule,
logging and restoration after abnormal termination. A `finally` block alone
cannot recover from PC power loss. Microsoft documents that `New-NetIPAddress`
disables DHCP (S7); removing the address alone does not restore original networking.
Such a network helper is not implemented.

## 6. Returning to OEM firmware

Use only the device's region and V3.30 OEM download (S8). An OEM web-update file
is not automatically a TFTP recovery image. Do not strip an arbitrary header,
apply v1/v3.0 recipes or overwrite the bootloader. Establish the exact file format,
supported recovery path and downgrade restrictions from TP-Link documentation
and this bootloader before use. If evidence is missing, OEM recovery remains
unresolved; use the previously verified OpenWrt recovery image instead.
For example, S8 warns that 1.10.0 Build 260303 cannot be downgraded. This applies
to that OEM release, not universally to all v3.30 firmware. The helper deliberately
rejects OEM images and performs no conversion.

## 7. Acceptance and next experiment

TFTP transfer, flash completion, kernel startup, network access and application
health are separate results. Record SHA-256, UART/TFTP logs, OS/kernel versions,
free flash/RAM, then test Ethernet, Wi-Fi, USB hub, ACM/RNDIS, audio and storage
according to the bench. Only then check core/demo and Modbus. A ping is not PASS.

Next separately approved experiment: capture UART for one failing image and verify
v3.30 recovery parameters. Host helper tests do not validate hardware recovery.
The project remains targeted at OpenWrt 19.07.9.

## Sources

- S1: [OpenWrt v3 support commit and TFTP procedure](https://github.com/openwrt/openwrt/commit/6bbb2202551be394fead2efd99eb946f846fc63d).
- S2: [OpenWrt v3 device page](https://openwrt.org/toh/tp-link/tl-mr3020_v3).
- S3: [OpenWrt v3 hardware profile](https://openwrt.org/toh/hwdata/tp-link/tp-link_tl-mr3020_v3).
- S4: official directories for [19.07.9](https://downloads.openwrt.org/releases/19.07.9/targets/ramips/mt76x8/), [19.07.10](https://downloads.openwrt.org/releases/19.07.10/targets/ramips/mt76x8/), [21.02.7](https://downloads.openwrt.org/releases/21.02.7/targets/ramips/mt76x8/), [22.03.7](https://downloads.openwrt.org/releases/22.03.7/targets/ramips/mt76x8/), [23.05.6](https://downloads.openwrt.org/releases/23.05.6/targets/ramips/mt76x8/).
- S5: [Tftpd64 author's repository](https://github.com/PJO2/tftpd64).
- S6: [Microsoft TFTP client](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/tftp).
- S7: [Microsoft New-NetIPAddress](https://learn.microsoft.com/en-us/powershell/module/nettcpip/new-netipaddress).
- S8: [TP-Link V3.30 EU/Nordic example; select your region](https://www.tp-link.com/nordic/support/download/tl-mr3020/v3.30/).
