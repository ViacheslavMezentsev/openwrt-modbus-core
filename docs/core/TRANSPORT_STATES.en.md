# Isolated transport states

[Русский](TRANSPORT_STATES.md) · [Accepted contract](TRANSPORT_CONTRACT.en.md)

Run `python3 scripts/test_transport_states.py`: 37 deterministic tests, also in
`make all` and `make ci-core`. [Model](../../scripts/transport_states.py) and
[tests](../../scripts/test_transport_states.py) are host-only Python, like the
previous rounds model. They add no router dependency and are excluded from IPKs.
The initial Python stage implements no socket/serial, sleep, OS clock, UCI,
Lua backend, grouping or modbusd integration. Queue/round composition is described below. Passing the model is not hardware evidence.

## Driving the model

Validity/last-success observations are separate for up to 32 logical devices;
this is not the runtime cache or TTL implementation.

A Transport represents one RTU line/TCP endpoint and one admitted operation.
States: idle, queued, setup, send, tx_completion, receive, retry, quarantine,
desynchronized. ready_at/retry_at express backoff.

- tick(ms) advances monotonic integer time and services deadlines/retry. Backward,
  fractional and Boolean timestamps are rejected. UTC is absent by construction.
- admit(Request, expiry) fixes Dop; begin() is the external scheduler decision.
  No automatic next-operation selection or queue is provided.
- setup_done(generation) supplies completion of preparation; wire exposes request
  bytes to the fake backend. tx(n, generation) reports accepted bytes; zero means
  EAGAIN, partial writes do not extend Da.
- tx_complete(generation) supplies externally confirmed TX completion. RTU errors
  require manual recovery without it, even after writing the full frame. No tcdrain
  or claim about real USB transmission is made.
- receive(bytes, generation) accepts at most 512 bytes per event; empty TCP input
  is EOF, empty RTU input is a no-op. io_error supplies backend failure.
- cancel preserves ambiguous write outcomes and line recovery. drain_results
  transfers the single terminal result; admission is blocked until consumption.
  This bounded observation slot is not the future event-delivery queue.

TCP callbacks require current generation. Close invalidates old callbacks before
reconnect. Deadlines run before processing bytes; if that closes the connection,
the callback is stale too. RTU starts unsynchronized. confirm_sync(evidence) records
an external assertion, not a hardware reset. A bounded timing_profile string is a
synthetic test assumption, not verification of hardware evidence. New instances
also need confirmation; automatic bounded startup is not modeled. Bytes exactly
at B can still be discarded; release is strictly after B and interframe silence.
Integer milliseconds round t3.5 upward to 4/2/2/2/2 ms for the supported baud rates.

Tests advance time between events. Methods do finite work, but the shared service loop belongs to the composition described below.

## Scope and coverage

FC01/02/03/04 validate unit/ranges/counts, MBAP/CRC, FC and exact response size.
FC06 probes write outcomes and echo; no runtime command allowlist is expanded.
Other writes and map loading are absent. safe_read is a trusted test input; the
future loader must source it from a map. Successful RTU reception assumes the fake
backend has already confirmed TX completion.

| Criteria | Host coverage | Remaining |
| --- | --- | --- |
| TC-111 | Dop/Da/setup, equality, partial TX/RX, pre-send expiry | Real clock/backend and queue |
| TC-112 | Retry limits/setup failures, unsafe reads/exceptions, no write replay | Production adapter/maps |
| TC-113 | Indistinguishable late RTU reply, manual block, independent peer | Real line/reconnect |
| TC-114 | Quarantine/B violation, partial/unconfirmed TX, startup/expiry | Hardware evidence/bounded startup |
| TC-115 | Every short-response split, coalescing, headers/PDU/cap/wrap/generation | Real socket/OS backpressure |
| TC-120 | not_sent/confirmed/unknown, cancellation, one terminal result | Readback/runtime commands |
| TC-121 | Gap rounding and bounded TX waiting | Wire timing/USB adapter |

TC-116/122 remain planned: UCI, compatibility and hotplug binding are absent.
TC-117–119 have partial composition coverage below; grouping remains absent. The previous 16
rounds tests retain their abstract-only scope.

## Queue and round composition (revision 1.21)

[transport_scheduler.py](../../scripts/transport_scheduler.py) composes the same byte
states. [15 tests](../../scripts/test_transport_scheduler.py) run with
`python3 scripts/test_transport_scheduler.py`, and in make all/ci-core.

enqueue retains admission time and caller expiry. Transport.admitted_at preserves
Dop and result start across queue waiting. FIFO holds 32 waiting operations per
endpoint (configurable 1..128), with active separate. Each periodic plan has at most
one pending entry beyond active; coalescing does not extend its deadline. Changed
pending plan parameters are rejected. This is polling coalescing, not read grouping.
Every queued entry is checked for expiry before selection, including non-heads.

step(now, events) accepts at most one event per endpoint. RTU membership is fixed
until every participant terminates, including retries. Early results return immediately;
quarantine after a terminal result no longer holds the barrier. Unready ports are
excluded. TCP progresses independently, with FIFO write/readback ordering.

The first endpoint rotates. Actual state-change counters enforce at most 8 transitions
per endpoint/pass; calls reserve transition headroom. One event bounds RX+TX to 512
bytes. The fake backend retains unconsumed input; Pass.consumed reports ownership
transfer. Pass.results transfers observations without scheduler history accumulation.
Up to 7×128 queued entries may expire per pass: finite, not a router RAM measurement.

post_ipc models a queue of up to 128 synthetic work units, serviced up to 8 per pass.
These are not real IPC wire quotas. next_wait uses nearest deadlines/quantum and
returns None for an idle external wait. CPU/RSS and OS/Lua/IPC latency are unmeasured.

Partial TC-117: 10/20/500 ms, late membership and retry; TC-118: independent TCP,
rotating order, bounded work/IPC; TC-119: FIFO, quotas/coalescing, enqueue deadlines,
non-head expiry. Full acceptance requires grouping, real backend/IPC and hardware.
Next: agree safe map ranges and implement read grouping, then Lua/backend fake I/O,
UCI and single-port integration. No router changes.

Revision 1.22 adds optional [safe-map grouping](READ_GROUPING.en.md) to this model. Earlier statements about absent grouping describe stage 1.21. Next: profile loading and production budgets, then Lua/backend.

## Isolated Lua states (revision 1.28)

[transport_state.lua](../../pkg/usr/lib/modbus/transport_state.lua) ports the
accepted Python state model to Lua 5.1. It ships in the IPK but modbusd does not
call it. CRC uses existing modbus.rtu; no new dependencies.
30 groups of [Lua tests](../../scripts/test_transport_state.lua) run in make all/ci-core.

API: transport_state.new(kind, options, clock); kind is rtu or tcp. Options use
model names: transport_id, request_timeout, operation_timeout, setup_timeout,
retries, retry_delay, reconnect_delay, policy, late_bound, timing_profile, baud.
Defaults/bounds follow TRANSPORT_CONTRACT. This is an internal core interface,
not UCI or a public client API. Unknown fields/types raise Lua errors before admission.

Optional clock returns monotonic integer milliseconds; without it use tick(ms).
Events consult the injected clock before processing. Backwards time is rejected;
deadline sums saturate at 2^53-1 rather than wrap. Do not manually tick ahead of
an external clock that has not advanced.

admit(request, expiry, admitted_at) copies the request. operation_id/device_id are
required; defaults are unit=1, function=3, address=0, count=1, safe_read=false.
begin selects the admitted operation; no queue yet. FC01–04 are reads; FC06 is
only the model's write probe, not new output permissions or runtime support.

Replaceable I/O is the event boundary: setup_done, tx(n), tx_complete,
receive(bytes), io_error. TCP requires the current generation; stale events are
ignored even if servicing the clock just closed the connection. wire contains
request bytes; sent counts acknowledged TX bytes. tx(0) represents EAGAIN.
tx_complete requires external TX completion evidence. A future real backend must
service deadlines BEFORE system calls; completion events do not authorize starting
expired I/O. The state engine makes no system calls.

Other methods: confirm_sync(evidence), cancel(), drain_results(). One result slot
blocks admission until consumed. Per-device valid/last_success (up to 32 devices)
is not runtime cache integration. RX caps are 256/520 bytes, with 512 bytes/event.
Aggregate per-pass byte/8-transition quotas, rounds and IPC belong to composition.
State fields are available to trusted drivers/tests, not a sandbox against extension
code. Admitted request tables are copied.

Tests cover every short-response split, largest frames, exact deadlines,
EAGAIN/partial TX, TX completion wait, retry/setup budgets, CRC/MBAP/exceptions,
manual/bounded quarantine including terminal outcomes, generations/TID,
write unknown/confirmed/not_sent and device/port isolation.

Next separate stage: Lua queue/round composition and quotas with fake I/O.
Native serial/socket, UCI, maps/reservations, installer, modbusd and hardware
timing/RAM remain incomplete and are not verified by this stage.

## Lua queue and round scheduler (revision 1.29)

[transport_scheduler.lua](../../pkg/usr/lib/modbus/transport_scheduler.lua)
composes states; [19 test groups](../../scripts/test_transport_scheduler.lua)
run in make all/ci-core (TC-132). The module ships in IPK but modbusd does not call it.
This is an internal trusted-driver API, not a public package interface.

- new(transports, options): dense list of fresh states with unique transport_id,
  up to 3 RTU and 4 TCP. The scheduler owns time exclusively; states with an
  external clock or existing work are rejected.
- enqueue(id, request, options): validates/copies through the shared
  transport_state.validate_request. Returns accepted, coalesced or busy;
  invalid contracts raise Lua errors. Up to 32 logical devices with fixed
  endpoint/unit bindings; aliases and duplicate pending/active operation_id
  on one port are rejected.
- Enqueue options: absolute expiry in monotonic milliseconds, periodic
  (1–32 byte key for reads), readback (boolean). Total lifetime starts at enqueue;
  waiting for a round does not extend it. Identical pending periodic work coalesces
  without replacing the original deadline/operation_id; changing the plan under
  the same key is rejected. Active operations and readback do not coalesce.
- step(now, events): monotonic integer milliseconds and at most one event per
  endpoint. kind: setup, tx, tx_complete, rx, error; data holds confirmed TX byte
  count or RX string. TCP requires the state generation. Returns results,
  consumed, order, transitions, io_bytes, round_started, ipc_serviced.
  The driver retains unconsumed events with their generation for a later pass.
  Complete batch shape is checked before time changes; semantic validity of
  completions (such as TX not exceeding remaining wire) is a trusted-driver contract.
- next_wait(): earliest deadline capped by quantum; nil means wait for an external
  event. post_ipc(n) only counts bounded synthetic work, at most 8 units per pass;
  it does not implement Unix IPC.

A round captures only ready RTU endpoints with work. Results return immediately;
retries remain in the same barrier. Terminal failure releases membership even
while a line remains quarantined. TCP is independent. Traversal order rotates.
Each pass services deadlines and expires the entire bounded queue, then handles
at most one I/O event per endpoint, with at most 512 bytes and 8 state transitions
per endpoint. Starting the next operation counts towards the same quota.

Scheduler options: queue_limit=32 (1–128) waiting entries per endpoint plus one
active operation, quantum=10 ms (1–100), ipc_limit=128 (1–128). These follow the host
model. At the maximum queue sizes, up to 903 results may return together
(7 × 128 plus 7 active); the scheduler does not retain returned results.
These object-count bounds are not measured RAM or CPU-time budgets.

FC06 remains a write test probe; writes/readback retain FIFO order.
Maps, read grouping, fragments and memory reservations are the next layer.
Native I/O, UCI, real IPC, modbusd and hardware timing/RAM are not verified here.

Revision 1.30: [Lua grouping](READ_GROUPING.en.md#isolated-lua-composition-revision-130) adds profiles/assembly_pool, fragments and active-group cancellation. The no-profile mode remains; backend/modbusd are disconnected.
