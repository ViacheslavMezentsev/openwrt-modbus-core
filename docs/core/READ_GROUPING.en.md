# Safe read maps and grouping

[Русский](READ_GROUPING.md) · [States and rounds](TRANSPORT_STATES.en.md)

Accepted core 4.7/6.8 contract. Host implementation:
[read_groups.py](../../scripts/read_groups.py),
[20 tests](../../scripts/test_read_groups.py). Run
`python3 scripts/test_read_groups.py`, also included in make all/ci-core.
Lua runtime, IPKs and the router are unchanged.

ReadMap/ReadRange are immutable typed objects, not a JSON/UCI loader. Unknown
fields, invalid integers, out-of-bounds addresses and same-function overlaps are
rejected. Adjacent ranges remain distinct merge boundaries. Addresses are zero-based
protocol offsets, not 40001 notation. FC01/02 quantities are bits, FC03/04 words.

| Field | Meaning |
| --- | --- |
| function | 1..4, separate address spaces |
| start/count | 0..65535 and positive quantity ending at or before 65536 |
| safe_read | Default false: no side effects, retries permitted |
| mergeable | Default false; requires safe_read |
| max_count | Default 1; 1..2000 bits or 1..125 words; device may lower it |
| max_gap | Default 0; unrequested addresses between requested spans, inside range |

Maps belong to logical devices. Scheduler derives safe_read from the trusted map,
not the client. With maps enabled, unknown devices/addresses fail before enqueue.
Existing unmapped host tests retain their isolated mode. Read maps do not authorize
writes; the existing FC06 model probe is unchanged, no FC15/16 support is added.

Only a compatible FIFO prefix is grouped: same device/unit/transport/function,
map range and retry policy (endpoint-owned in the model). Overlaps/duplicates are
allowed; gaps must fit max_gap and every address must be in the same safe range.
An incompatible or oversized candidate stops selection; later entries are not skipped.
Writes are neither merged nor deduplicated. Explicit readback is a barrier on both
sides; a safe oversized readback may split but cannot merge with polling.

A large safe logical read splits into sequential wire requests, without merging
other consumers in this version. Unsafe oversized reads are rejected rather than
silently changing side effects. All fragments retain original Dop and order.
Each wire request has its bounded retry budget; result counters sum fragment attempts.
Exceptions terminate the operation without fallback splitting/retry. RTU fragments
stay inside the original round operation, observing line gaps; peers keep progressing.
Expiry applies between fragments too. Split reads are not atomic device snapshots;
a single response does not prove atomic device register updates either.

The group uses earliest Dop. Fan-out preserves consumer IDs/start and shares the
completion timestamp. Bit slices are repacked from bit zero with zero padding.
Any fragment failure returns empty payload for affected consumers, clears valid,
and retains the previous complete last_success. Partial success is never published.
Original consumers retain quota: active plus waiting <= queue_limit + 1. Grouping
cannot create an unbounded subscriber list or extend deadlines.

Revision 1.23 adds [profile loading and limits](DEVICE_PROFILES.en.md): 64 ranges
per profile, 1024 result bytes, 16 fragments/consumers and an 8 KiB assembly pool.
Lazy fragments and packed data replace the earlier broad prototype allocations.
These bounds do not constrain total process RAM.

Partial TC-69–71/119 coverage: map boundaries/holes/functions/gaps, FIFO/write/readback,
deadlines/quotas, duplicates, bit offsets, splitting and fragment failure. Production Lua map
loading, device profiles, IPC and hardware safety evidence remain planned.

## Isolated Lua composition (revision 1.30)

[read_groups.lua](../../pkg/usr/lib/modbus/read_groups.lua) and
[transport_scheduler.lua](../../pkg/usr/lib/modbus/transport_scheduler.lua)
now implement this contract in Lua 5.1.
[26 test groups](../../scripts/test_read_groups.lua) run in make all/ci-core:
boundaries/holes, FC01–04, FIFO/write/readback, bit/register fan-out, deadlines,
limits, memory waits, cancellation/failure/retries and the RTU barrier.
This is TC-133 and partial TC-69–71/119/125/126 coverage; native backend and
modbusd remain disconnected.

The internal scheduler.new(transports, options) API adds options.profiles:
a snapshot from device_profiles store:activate/current. Forged tables are rejected;
device_profiles.is_snapshot identifies views issued by the loader.
The scheduler retains that snapshot; later store activation does not change it.
An explicitly supplied empty snapshot still rejects unknown device reads.
Without profiles, the previous isolated single-wire test mode remains available.
Arbitrary map tables and hot replacement are unsupported.

enqueue checks logical size (up to 8192 bits / 512 registers), single-range
containment and fragment count before queue mutation. The profile owns safe_read;
clients cannot override it. transport_state:admit still accepts wire sizes only.
validate_request(request, kind, logical) with logical=true is used only for
preliminary logical-request validation.

A group selects at most 16 compatible FIFO-prefix consumers. Active consumers
plus pending entries remain at most queue_limit + 1. Every original operation_id
is retained and checked for duplicates, including interfragment gaps.
Retries apply per wire request; attempts/sent_attempts accumulate.
After intermediate success, both endpoint and samples[device] valid/last_success
describe only the previous full observation, with valid=false. Later failure
cannot retain an intermediate fragment's success timestamp.

options.assembly_pool accepts read_groups.pool(limit), 1–8192 bytes;
the default is a private 8192-byte pool. used(), acquire(owner, bytes) and
release(owner) are for trusted core/test code. A pool may be shared between
schedulers to model shortage. Full logical payload is reserved before dequeue
or RTU-round membership; memory_blocked records a refusal in the current pass.
step retries admission; next_wait remains capped by quantum/deadline and does not
spin at zero solely because memory is unavailable. Shared-pool release may trigger
an external wakeup; there is no pool callback yet.

cancel(endpoint) cancels the entire active group, including interfragment gaps,
and returns a boolean. The next step returns results and releases its reservation.
This is internal cleanup, not a public per-consumer cancellation API.
Pending queue entries are unaffected. The caller must keep stepping until
completion; simply dropping a scheduler with a shared pool is not cleanup.

Assembly retains a packed Lua string and computes the next wire request by index.
It retains neither all fragments nor a table of all bits.
String concatenation temporarily holds old and new payloads; bit packing uses a
temporary byte table and fan-out allocates result strings.
With 7 transports, retained assembly payload is at most 7168 bytes, but copies,
metadata, JSON, RX/TX, step results and memory awaiting GC are outside the
8192-byte reservation. IPK size/payload bounds do not establish peak RAM or GC
latency on MR3020.

The next stage is a separate bounded native-I/O contract/implementation;
total Lua RAM measurements remain required before integration.
Real device profiles, UCI, installer and modbusd are unchanged by this stage.
