# Device profile loader and limits

[Русский](DEVICE_PROFILES.md) · [Read maps](READ_GROUPING.en.md)

Accepted core 6.9 contract (revision 1.23), host-only implementation:
[loader](../../scripts/device_profiles.py), [limits](../../scripts/profile_limits.py),
[21 tests](../../scripts/test_device_profiles.py).
Run `python3 scripts/test_device_profiles.py`, also in make all/ci-core.
No modbusd, IPK, UCI, router or installation changes.

## Files and trust

Target installed directory: `/usr/share/modbus-rtu-core/profiles/`, supplied by
trusted packages. IDs match `[a-z0-9][a-z0-9_-]{0,31}`, the canonical `<id>.json`
filename and device map reference. Ports, unit and polling schedules belong to
device instances. The package supplies the distribution version; JSON has no
additional version fields. See the [JSON example](DEVICE_PROFILES.md).

Required root fields: id/read_ranges; required range fields: function/start/count.
Other fields use accepted map defaults. Reject unknown fields, duplicate keys at
all levels, NaN/Infinity, invalid UTF-8, fractions/booleans as integers, wrong types,
empty maps and overlaps. Root object -> array -> range objects allows at most three
nesting levels, checked before decode. Bound raw input to 16384 bytes with a limit+1
read. Profiles contain data only; no Lua execution, dependencies or network fetching.

The host caller provides a trusted fixture directory and `{device_id: profile_id}`
bindings. Open the directory once and selected canonical files relative to its fd;
reject symlinks/nonregular files and avoid blocking on FIFOs. A canonical filename
prevents alternate search-path overrides. Package ownership collisions must be
rejected by installation rather than file replacement. Trusted directory ownership
is a model assumption, not implemented production supplier verification. Parsing
does not establish the safety of the actual device map.

## Activation

ProfileStore.activate requires maintenance=True and active_operations=0. Validate
bindings, load unique selected profiles, validate aggregate limits, then publish
immutable profiles/bindings/maps. Multiple devices share one decoded map. Unselected
files are ignored. Any failure preserves all previous objects; a cold failure leaves
empty state and returns an error, without fallback. Maintenance/idle are caller
assertions in this host API, not a modbusd quiescing mechanism. Scheduler receives
validated bindings/maps; existing schedulers are never hot-swapped automatically.

| Object | Limit |
| --- | --- |
| Raw JSON profile | 16384 bytes |
| Ranges/profile | 64 |
| Unique selected profiles | 16 |
| Total selected ranges | 256, shared maps counted once |
| Logical devices | 32 |
| Logical result payload | 1024 bytes: 512 words or 8192 bits |
| Fragments/logical read | 16, in addition to byte limit |
| Consumers/group | 16, remainder stays FIFO |
| Total assembly reservations | 8192 payload bytes |

Check payload size and ceil(count/max_count) before enqueue. Exceeding limits
rejects without truncation or queue mutation. Waiting requests hold descriptions
only. Reserve the complete assembly before launch; insufficient memory leaves the
request queued with its original deadline and outside a new RTU round. Peers/IPC
continue. Hold the reservation across fragments and release on every terminal
outcome, including failure, cancellation and interfragment expiry.

A scheduler owns its pool; tests inject a smaller/shared pool to exercise contention.
Seven current endpoints with one 1024-byte assembly each need at most 7168 bytes,
so the default 8192-byte pool has headroom. Pool saturation is a synthetic test,
not measured router memory exhaustion.

WireSequence produces fragments lazily. Assembly uses packed bytearray storage,
including bits, without a per-bit table. Consumer results are constructed one by
one, but model Pass.results retains copies until handed off. Those copies, JSON,
Python/Lua objects, RX/TX, cache and IPC are outside the reservation budget.
8192 is a payload limit, NOT total RAM consumption or an MR3020 measurement.

The [strict Lua decoder](STRICT_JSON.en.md) is bundled; legacy decode retains optional
luci.jsonc. Next: Lua loader with depth=3 and schema validation, installed catalogue ownership, add evidenced hardware profiles
and measure decode/fan-out/IPC memory peaks. The loader uses WSL/Linux POSIX directory
fd APIs; it is not a ready Lua backend or native Windows Python implementation.
