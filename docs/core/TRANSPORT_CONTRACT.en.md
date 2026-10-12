# RTU/TCP transport contract — accepted profile

[Русский](TRANSPORT_CONTRACT.md) · [Core specification 1.20](TECHNICAL_SPECIFICATION.md)

12 October 2026. The owner accepted revision 1.19 policies and software limits.
This is a target contract, not the released core 0.4.0 API. Revision 1.20 adds
[isolated states](TRANSPORT_STATES.en.md), with partial host coverage of
TC-111–115/120/121. Runtime and hardware are unchanged; other tests remain planned.
Requirements: core 6.8.1–6.8.18.

## Scope and deadlines

One serial owner and one request per RTU port/TCP connection. Direct RTU ports
share a round; TCP endpoints advance independently of that barrier. Gateway
internal scheduling is independent. No TCP server, TLS, network/RNDIS setup or
expansion of permitted device functions is introduced.

All clocks are monotonic. Admission at t0 starts Dop=t0+operation_timeout_ms,
capped by caller expiry. Queue/barrier waiting, open/config/connect, transmission,
response, retries, quarantine and reconnect all consume it. No UTC change,
fragment or retry extends it. Attempt timing starts immediately before the first
send attempt after setup/interframe waiting: Da=min(Dop,start+request_timeout_ms).
A complete validated response must be processed at now<Da; equality is timeout,
even if bytes already sit in the OS buffer. Check deadlines before side effects.
Setup has min(Dop,start+setup_timeout_ms). Unbounded calls are not a usable backend.

One terminal result: ok, expired before send, timeout, io_error, protocol_error,
modbus_exception, desynchronized, cancelled or config_error. Queue rejection is
busy before admission. Results identify logical device, transport, operation,
attempts, monotonic start/end, optional exception_code and write_outcome. Writes
are not_sent, confirmed or unknown. Any potentially transmitted write without a
valid confirmation is unknown. Reconnect/readback cannot prove nonexecution;
readback is a separate observation. Failures clear valid while keeping last_success.

## Retries and late RTU responses

read_retries=R permits at most 1+R attempts, including setup/connect failures.
Diagnostics also count attempts that sent bytes. Partial I/O and EAGAIN continue
an attempt; EINTR rechecks its deadline; TCP zero read means EOF. Only map-declared
safe_read FC01/02/03/04 operations are retryable. Retryable classes are timeout,
connect/I/O failures and RTU CRC/framing errors after permitted recovery. Every
Modbus exception (including 06), invalid configuration/map, unexpected TCP protocol,
write or cancellation is terminal in this profile. Delay and recovery must fit Dop.

RTU has no transaction ID; same-unit/function/count reads of different addresses
can produce indistinguishable responses. Flush, reopen and t3.5 silence do not
cancel pending remote work. The profile assumes one master and no unsolicited
traffic; it is not protection against malicious devices.

Default resync_policy=manual: timeout/disconnect/CRC/framing error after sending
marks the entire port desynchronized. The operation terminates; other ports
continue. New traffic requires confirmed device/line reset or an evidenced timing
profile. Reopen/process restart alone does not reset this state. Unknown startup
synchronization also needs confirmation; the core is not authorized to reset hardware.
Cancellation or Dop expiry after possible transmission applies the same resync policy;
a terminal operation result does not imply that the line is ready for another request.

Optional bounded requires late_response_bound_ms=B and timing_profile evidence
covering all devices on the line. B bounds arrival of ALL response bytes at the
host after the last successful request write, including queued TX/RX, USB/OS and
device delays. A measured average or observed maximum is not a proven bound.
There is no universal B default. After a fully sent request, quarantine drains
bounded chunks without updating data until last_write+B and the interframe quiet
period after the last received byte. Traffic beyond B violates the profile and
marks desynchronized. Dop expiry terminates the operation, releases the barrier,
and leaves the port quarantined until safe. Partial TX or unknown queued TX always
requires manual resync in the first profile. Startup/reconnect automation is allowed
only if the timing profile covers it; otherwise confirmation is required. A successful
transaction assumes no duplicate responses; unsolicited idle bytes desynchronize.

## TCP

Accept MBAP protocol_id=0, Length 2..254, ADU up to 260 bytes. Match connection
 generation, transaction ID, Unit, FC/exception and PDU semantics. Split frames
accumulate; coalesced frames follow Length. RX capacity is 520 bytes, reads fit
remaining space; malformed lengths/overflow close the connection.

Use IDs 0..65535 once per connection; reconnect with a new generation before
reuse. Old-fd callbacks cannot affect a new generation. Timeout, cancellation after possible transmission, EOF, failed
partial write or protocol violation closes the connection. A safe read may retry
eligible failures on a new connection within Dop. Unexpected MBAP/Unit/FC/ID is
terminal, not retryable. An extra frame closes the connection and cannot finish
another operation or undo a result already delivered. This is a deliberately
strict client policy, not a universal Modbus requirement.

## Accepted limits and scheduling

These are accepted software bounds, not measured MR3020 guarantees. Milliseconds
are integers; unknown fields, fractions and overflow are rejected.

| Parameter | Default | Range |
| --- | --- | --- |
| request_timeout_ms | 500 | 100..2000 |
| operation_timeout_ms | 10000 | request_timeout_ms..60000 |
| setup_timeout_ms | 1000 | 100..5000, capped by Dop |
| read_retries | 0 | 0..3 |
| retry_delay_ms | 100 | 0..5000 |
| reconnect_delay_ms | 1000 | 1000..30000; never bypasses resync |
| late_response_bound_ms | none | 1..60000, bounded policy only |
| queue_limit | 32 | 1..128 waiting operations per endpoint |
| io_quantum_ms | 10 | 1..100, global maximum poll wait |

At most 3 active RTU ports, 4 TCP endpoints, 32 logical devices. RTU RX 256 bytes,
TCP RX 520. One active operation is separate from queue_limit; retries retain it.
FIFO, prune expired entries, at most one pending periodic operation per read plan.
No catch-up backlog of missed polling periods. Grouped reads retain the earliest
Dop and compatible safe_read/retry policies/maps/functions; original consumers
still consume quota. Writes/readback preserve their ordering barrier.

Each pass allows at most 8 state transitions and 512 total RX+TX bytes per transport,
then peers and IPC are serviced. Rotate the first endpoint. Invoke bounded IPC
service each pass; exact IPC wire quotas belong to Event API work. Wait until the
nearest deadline/readiness/quantum; expired timers poll with zero timeout, idle
systems block rather than spin. Quantum is not a bound on OS or callback latency.

RTU round membership is a fixed set of ready FIFO heads after grouping. Retries
remain in the same operation/round. Fast ports publish immediately but cannot
start their next operation before the barrier. Later requests enter a later round.
Offline/backoff/desynchronized ports are excluded; their queued operations still
expire. TCP uses the same bounded service loop without joining the RTU barrier.
The maximum round duration follows participant Dop; no separate round_timeout.

## Configuration

New UCI transport/device sections in modbus-rtu-core; IDs match
`[a-z0-9][a-z0-9_-]{0,31}` and are unique within their type. Transport fields:
enabled=1 (0/1), required type=rtu/tcp, role=modbus-client, timing/queue fields above.
Other roles are rejected. RTU requires /dev/ttyACM<number> or /dev/ttyUSB<number>
and baudrate in 9600/19200/38400/57600/115200. Fixed data_bits=8, parity=N,
stop_bits=1, flow_control=none; BluePill only 115200. This bench 8N1 profile does
not claim full serial-guide conformity. No GPIO DE/RE control; a verified adapter
owns direction. Settings belong to the line, not individual units. Before opening,
validate a character device and reject duplicate major/minor identities. Fixed
paths do not identify USB hardware: reconnect after hotplug in the new configuration
requires operator binding verification until a stable resolver exists.

TCP requires numeric IPv4 address and port=502 default (1..65535); DNS/IPv6 later.
Reject duplicate address/port endpoints; units share a connection. No network
settings change. Device fields: transport reference, unit (RTU 1..247; TCP 0..255
as explicit server-supported route, never translated into RTU broadcast), registered
map profile. Reject duplicate transport/unit. Maps/safe_read need a separate loader
contract; fields cannot introduce arbitrary paths or executable code.

See the [Russian example](TRANSPORT_CONTRACT.md) for illustrative UCI; it is not
accepted by current modbusd. Unknown maps are rejected. New logical IDs own
/devices/<id>/... and cache keys; unit is metadata. With no new sections, the
legacy core.main path and its topics/cache remain unchanged, without claiming the
new strict resync behavior for the old backend. Reject active legacy device/profile
mixed with new sections. No automatic migration: explicit maintenance transition,
backup, no active operations. Validate all configuration before activation; do not
remove/rebind active operations.

## Timing and verification

Use t3.5: 3.5 characters through 19200 baud, 1.75 ms above it. For bench 8N1 use
10 bits/character: at least 3.646 ms at 9600 and 1.823 ms at 19200, round upward.
Never reduce required silence. TX completion must be bounded and confirmed or
conservatively bounded by the adapter contract, not an unbounded tcdrain. USB
chunks are not wire-byte timestamps: do not infer t1.5 wire conformance from read()
gaps. Validate length/CRC/unit/function; strict RX timing needs adapter guarantees
or hardware evidence. Existing 16 model tests do not supply that evidence.

TC-111–122 cover: deadline boundaries/UTC; retry budgets and forbidden replay;
indistinguishable late RTU replies; bounded quarantine and violations; TCP splits,
coalescing, bounds/ID wrap; configuration refusal; 10/20/500 ms rounds and in-round
retry; independent TCP/IPC servicing; queue/coalescing fairness; unknown write
outcomes; line timing/USB limits; legacy compatibility. Host coverage is partial; unimplemented cases remain planned, including
hardware checks after separate approval. See the core specification for individual
acceptance criteria and traceability.

Protocol references: [Serial Line V1.02](https://www.modbus.org/file/secure/modbusoverserial.pdf)
and [TCP Guide V1.0b](https://www.modbus.org/file/secure/messagingimplementationguide.pdf).
Manual/bounded recovery, budgets, strict TCP policy and UCI are accepted project
choices, not instructions from Modbus Organization.
