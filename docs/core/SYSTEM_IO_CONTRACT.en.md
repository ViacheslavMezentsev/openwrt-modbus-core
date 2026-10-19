# Core system I/O adapter: accepted requirements

[Русский](SYSTEM_IO_CONTRACT.md) · [Core specification](TECHNICAL_SPECIFICATION.md) · [Transport](TRANSPORT_CONTRACT.en.md)

19 October 2026. Boundaries and acceptance criteria are accepted; implementation
is absent. This is a future serial/socket backend, not the existing
modbus.system_io button/LED handler. No renaming or modbusd integration.

## Ownership and execution

The adapter exclusively owns descriptors. Transport states own protocol/deadlines,
the scheduler owns queues/rounds/reservations, and the command layer owns session
permission. Packages receive no descriptors and cannot write directly.

Open/config/connect/read/write/TX-completion and cleanup must have bounded
execution. A timer around an unbounded syscall is insufficient. Choose and verify
syscalls, nixio/native-helper capabilities and ownership before implementation;
a helper must not create a second serial owner. No synchronous DNS or arbitrary
shell in a working pass; resolution requires a separate bounded mechanism.

Before every write, including partial-TX continuation and EINTR, reread monotonic
time and check Dop/Da, operation identity and permission. At equality no new bytes
are sent. Account for short writes exactly; EAGAIN must not loop until success.
Service deadlines before readiness and after syscall return. Previously accepted
OS bytes may still be transmitted later.

Retain 512 bytes/8 transitions per endpoint/pass. Syscall/retry loops need an
explicit finite budget; its numerical value is still open. Reads respect remaining
RX capacity. Poll waits are capped by the earliest deadline/quantum; cancellation
and revocation require wakeup without spinning. Call duration and total RAM
require separate measurements.

## Identity and completion

Events carry endpoint, connection generation and a unique operation/attempt
context. Old readiness/completion cannot affect a reused fd, reconnect, retry or
next request on the same connection. A client operation_id alone does not
distinguish attempts. Exact API fields remain open; existing fake I/O does not
implement the full system contract.

OS write success is byte acceptance, not board application. RTU completion needs
verified adapter support or a justified upper bound; USB queues are not the wire.
Unbounded tcdrain is forbidden. Unverified capabilities are unsupported.
TCP send completion is not Modbus acknowledgement either.

Cancellation/expiry stop further writes without retracting accepted bytes.
Possible write transmission without a correct response means unknown; close,
flush or readback cannot turn it into not_sent. Produce one terminal result
and clean up operation resources; quarantine/desynchronization is separate.
Bounded close and partial-setup/error/repeated-cancel cleanup must be verified.
Scheduler releases assembly reservations, descriptor owner releases descriptors.

## Dependent command-layer contract

These are accepted boundaries for future work, not an implemented command API.

| Context | Meaning |
| --- | --- |
| operation_id | Operation identity |
| session_generation | Control-permission generation |
| sequence | Ordering within a session |
| expires_at | Absolute deadline on router monotonic time |

Lifetime includes queue/setup/TX/response and is not extended by reconnect.
Browser clocks are untrusted. A short-lived router-issued permission must bound
acceptance of delayed commands; receiving an old message cannot grant a fresh TTL.
Sequence alone does not bound age. Delays to the board require board-side
permission expiry, not direct comparison of unsynchronized clocks.

Ordinary writes remain FIFO and are never merged. An explicitly permitted setpoint
stream may replace only an unstarted setpoint for the same session/device.
Displaced requests get terminal results; codes, quotas and permissions remain
a separate contract. An in-progress frame cannot be replaced.

STOP revokes permission, removes queued setpoints for that permission and
prioritizes a safe-state command over ordinary waiting work. It cannot interrupt
a frame or bypass RTU quarantine/desynchronization. Scheduling against rounds,
resources and active work remains open; the current fixed barrier is unchanged.
Delivery over a failed link cannot be promised. UI distinguishes requested,
confirmed and unconfirmed stopping.

Rover owns hold/video policy and controller ownership. The board owns independent
watchdog, no automatic rearming, coherent wheel-setpoint application and application
acknowledgement. Only fresh authorized control renews the watchdog, not arbitrary
polling. Write acknowledgement, applied setpoint and physical stop are distinct.
TTL/heartbeat/watchdog values and brake/coast belong to the rover/board profile;
this document neither selects them nor extends the write allowlist.

## Planned verification

| Core TC | Injected system I/O | Expected |
| --- | --- | --- |
| TC-134 | Deadline/revocation before write, partial TX, EINTR | No new bytes after expiry check; not_sent/unknown distinguished |
| TC-135 | EAGAIN/noise, slow setup/connect, idle system | Finite work, other ports/IPC progress, no spin; unbounded calls rejected |
| TC-136 | Reused fd, old connection/operation/retry event | No effect on the new attempt |
| TC-137 | OS-accepted TX not drained, error/cancel | No false completion/confirmation or resync bypass |
| TC-138 | Every setup failure, repeated cancel, timeout, shutdown | One result, descriptor/reservation cleanup, quarantine preserved |
| TC-139 | Full setpoint queue/STOP, active read/write, RTU quarantine | Dependent command-layer test: no replay/interleaving or automatic rearm |

Old model results do not establish backend PASS. Fake-I/O tests precede host
capability/memory checks; hardware timing/watchdog tests need separate approval.
No network, firmware or router changes are part of this stage.
