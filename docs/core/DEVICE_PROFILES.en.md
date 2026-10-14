# Device profile loader and limits

[Русский](DEVICE_PROFILES.md) · [Read maps](READ_GROUPING.en.md)

Accepted core 6.9 contract (revision 1.23), original host model:
[loader](../../scripts/device_profiles.py), [limits](../../scripts/profile_limits.py),
[21 tests](../../scripts/test_device_profiles.py).
Run `python3 scripts/test_device_profiles.py`, also in make all/ci-core.
The Lua module now ships in the IPK; no modbusd, UCI, router or installation changes.

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
luci.jsonc. Lua schema/activation is now isolated and tested. The [system reader](PROFILE_READER.en.md) passed host and isolated target tests. Next: installer coordination, add evidenced hardware profiles
and measure decode/fan-out/IPC memory peaks. The loader uses WSL/Linux POSIX directory
fd APIs; it is not a ready Lua backend or native Windows Python implementation.

## Isolated Lua loader

[device_profiles.lua](../../pkg/usr/lib/modbus/device_profiles.lua) ships in the IPK;
modbusd does not call it yet. It uses the bundled strict decoder with depth=3 and
the same schema/limits as the host model. 19 groups of [Lua tests](../../scripts/test_device_profiles.lua)
run in make all/ci-core.

- loader.decode(text, expected_id) returns a profile or nil, {code=...}.
  JSON errors use the json_ prefix and byte offset.
- loader.new(read_profile) creates a store; missing reader returns reader_required.
  No implicit io.open, shell or path search.
- store:activate(bindings, maintenance, active_operations) returns a new snapshot
  or nil, {code=...}. Explicit true and 0 required; reentrant activation returns busy.
- store:current() retains the previous snapshot until complete candidate publication.
  Failure in the last file does not publish earlier candidates.
- snapshot:profile(device), :binding(device), :devices(), :profile_count(),
  :range_count() expose configuration. devices returns a copied list.
- profile:id(), :count(), :range(index) expose profiles. range returns a copied
  normalized record, sorted by function/start with model defaults.

Shared profiles are read once per activation. Views hide data and reject ordinary
assignment. Old snapshots remain valid after replacement. This guards accidental
API mutation, not malicious rawset/debug from trusted Lua code. Retained snapshots
retain memory.

read_profile(id, maximum_bytes) is a synchronous trusted system adapter callback,
not profile/client code. It receives a canonical ID and 16385 (limit+1), returning
a string or nil, error; exceptions become read errors. The loader bounds returned
input, not callback allocations or execution time. Bindings are copied/validated
before I/O; unique IDs are sorted and unselected profiles are not read.

The [system adapter](PROFILE_READER.en.md) checks Unix ownership, directory
walk/descriptors and bounded reads; mock/native Linux tests passed.
Isolated target checks are accepted; package provenance, installer coordination and integration remain.
Maintenance/active_operations are caller assertions, not transport quiescence.
Schema validity does not prove device safety.
