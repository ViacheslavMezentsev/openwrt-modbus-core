# System profile reader

[Русский](PROFILE_READER.md) · [Loader](DEVICE_PROFILES.en.md)

profile_reader.lua ships in the IPK, without modbusd integration. Uses the existing
luci-lib-nixio dependency; no new package dependencies.

## API and trust

reader.system() returns the device_profiles.new callback or nil, {code=...}.
Fixed catalogue: /usr/share/modbus-rtu-core/profiles.
Callback accepts canonical ID and exactly 16385 (16384+1), returning bytes or
nil, {code=...}. I/O exceptions are contained; loader reports read failures.

reader.new(nixio_backend, absolute_root) is a test/trusted-core interface, never
client paths. Limit 256 bytes/16 components; no empty/dot components, NUL or trailing
slash. No shell, io.open or fallback reducing protection.

All directories from / and the file must be UID 0 owned, without group/other write.
Profiles must be regular files, one hard link, at most 16384 bytes. No symlinks;
root-owned /tmp mode 1777 is rejected. Unix ownership does not prove package
signatures or absence of opkg ownership conflicts.

## Algorithm

Open / and hold parent descriptors. Walk /proc/self/fd/N/name with O_DIRECTORY,
O_NOFOLLOW, O_CLOEXEC and O_NONBLOCK. The procfs descriptor link is intentional;
catalogue components are no-follow. Compare pre-open lstat to fstat: type, UID,
permissions, dev/ino/nlink.

Read chunks up to 2048 bytes, at most limit+1; reject more than 16384.
Continue short reads; read errors terminate. Reject FIFO before open, with NONBLOCK
also guarding FIFO replacement. Recheck descriptors/names through pinned parents
after reading; include file size/mtime/ctime and actual byte count.
Close all descriptors in reverse order on every outcome. Close errors invalidate
success but remaining cleanup continues; no close retry.
At most 18 FDs for a 16-component test root, 6 for the fixed catalogue.

## Platform and limits

API checked against [nixio 19.07 source](https://github.com/openwrt/luci/tree/f25285a6c26e8776f153994704710cb8e51fad91/libs/luci-lib-nixio/src).
Named nofollow/directory/cloexec are unavailable: Linux UAPI 131072/65536/524288
are used; NONBLOCK comes from nixio.
Sources: [asm-generic](https://github.com/torvalds/linux/blob/v4.14/include/uapi/asm-generic/fcntl.h),
[MIPS](https://github.com/torvalds/linux/blob/v4.14/arch/mips/include/uapi/asm/fcntl.h).
Only Linux mips/mipsel and host x86_64 accepted. Missing nixio/procfs fails closed.
Isolated OpenWrt/MIPS verification is accepted; conditions are recorded below.

Installation must not modify files/catalogue concurrently with activation.
Metadata checks detect tested replacements, not hostile root, same-metadata
in-place writes or mixed generations across files. nixio timestamps have second
resolution. Mount namespace/procfs are trusted. NONBLOCK does not bound disk I/O
latency; total RAM/latency unmeasured. Package provenance and installer coordination
remain separate work.

## Tests

make all/ci-core: 13 groups in test_profile_reader.lua cover arguments,
ownership/modes/types/links, open/stat/read/close faults, replacement/growth/limits
and preservation of the active configuration.

Separate test_profile_reader_native.py runs real nixio on a Linux host as root:
real files/modes/FIFO/links/sizes, three open/read replacement races and FD stability
after 200 reads. Temporary fixtures are created/removed under /root, not a router.

To repeat, build host Lua 5.1/nixio at the pinned revision; configure LUA_BIN,
LUA_PATH, LUA_CPATH and optionally LD_LIBRARY_PATH. From the repository run
python3 scripts/test_profile_reader_native.py as host root.
Native tests are outside make all; mock success does not replace them.

## Accepted target verification — 2026-10-15

Code c68dec5 was tested on MR3020 v3.30, OpenWrt 19.07.9, kernel 4.14.267,
Lua 5.1, machine=mips; luci-lib-nixio git-22.045.73925-36e5c1c-1.
Isolated module/test copies matched SHA256; the installed core was not upgraded.

PASS: 20 strict JSON groups, 19 schema/activation groups, 13 reader fault groups.
Real filesystem checks covered permissions/UID, sizes, FIFO, symlinks and hardlinks;
three open/read replacements were rejected. FD count did not grow after 200 reads.
The real reader -> loader activated a profile and preserved its snapshot on a later
read failure. The system() factory initialized successfully.

Positive reads used a separate trusted temporary directory under /root.
The production catalogue was neither created nor read through system().
30 installed-file/configuration hashes and core/demo PID/starttime remained unchanged.
Core stayed online/valid with fresh BluePill/demo data. Fixtures were removed;
no serial access, modbusd integration or service restart.

This accepted isolated observation is not a general platform guarantee.
Transport integration, installer exclusion, package provenance, long-term operation
and total RAM/CPU/latency remain unverified. Raw hardware logs/fixtures stay outside Git.
