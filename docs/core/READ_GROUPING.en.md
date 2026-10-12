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
