# I/O adapter: host checks and test API

[Русский](IO_ADAPTER_API.md) · [Contract](SYSTEM_IO_CONTRACT.en.md)

Revision 1.32, 22 October 2026. [io_adapter.lua](../../pkg/usr/lib/modbus/io_adapter.lua)
ships as an isolated module with no default system calls.
[20 test groups](../../scripts/test_io_adapter.lua) use injected primitives.
It is disconnected from transport_state/scheduler/modbusd, not a working native backend.

## Evidence

Reviewed nixio openwrt-19.07 commit f25285a6c26e8776f153994704710cb8e51fad91:
[file.c](https://github.com/openwrt/luci/blob/f25285a6c26e8776f153994704710cb8e51fad91/libs/luci-lib-nixio/src/file.c),
[io.c](https://github.com/openwrt/luci/blob/f25285a6c26e8776f153994704710cb8e51fad91/libs/luci-lib-nixio/src/io.c),
[poll.c](https://github.com/openwrt/luci/blob/f25285a6c26e8776f153994704710cb8e51fad91/libs/luci-lib-nixio/src/poll.c).
Read/write contain hidden EINTR loops, preventing Lua deadline checks and exact
four-call accounting. The new path needs a minimal native single-call layer;
existing nixio users are unchanged. This commit does not identify the installed router library.

Linux WSL2 x86_64 probes passed CLOCK_MONOTONIC, eventfd/poll, nonblocking loopback
TCP connect/SO_ERROR/data/EOF and raw/nonblocking PTY. PTY TIOCOUTQ returned zero;
TIOCSERGETLSR returned ENOTTY. These establish host availability, not syscall time
bounds, USB TX timing or OpenWrt support. Probes ran separately with an overall
timeout and are not promoted to hardware CI evidence.

## Trusted driver API

new(sys, capabilities) requires explicit primitives, no nixio/io.open fallback.
single_call/bounded_setup/bounded_close must be true; rtu_tx_complete is boolean.
These are trusted backend declarations, not automatic certification.
RTU without TX capability is rejected before opening.

| Method | Purpose |
| --- | --- |
| prepare(id, config, token, deadline) | Copy context and schedule preparation; no syscall yet |
| service(id, permit, ready) | At most 4 primitives, 512 bytes and one returned event |
| transmit(id, token, bytes, deadline) | 1–260 byte wire buffer; deadline may only shorten |
| finish(id, token) | Parser completed response; retain idle connection |
| begin(id, new_token, deadline) | Next operation/attempt on idle connection |
| cancel(id, token) | Subsequent service returns error then cleanup |
| close(id) | Shutdown cleanup; transport owner must already handle operation outcome |
| wait(timeout_ms) | One poll, no EINTR retry; one drain if woken |
| notify() | One nonblocking wake, coalescing repeated notifications |
| capabilities() | Copy of backend declaration |

token={connection,operation,attempt}, positive integers through 2^53-1.
Operations/attempts strictly increase; reopen requires a higher connection.
Exhaustion stops the lifecycle rather than wrapping. Client IDs are separate.

config: kind, address, TCP port or RTU baud. This is a test API shape, not UCI/USB
identity validation. Production supplies validated configuration and numeric TCP
addresses without DNS. permit(token) is a trusted bounded synchronous permission
check. Reread the clock after the callback and syscall.

sys: clock, open, configure, connect, connect_status, write, read, tx_empty, close,
poll, wake, drain_wake. Each transport primitive is exactly ONE syscall without
hidden retries. configure only applies prepared termios; it cannot bundle
tcgetattr/tcsetattr. Additional native setup steps must be explicit states and
consume budget. Return a value or nil/normalized errno. tx_empty=false means
unconfirmed completion. TCP completion is not Modbus acknowledgement.
A write exception conservatively marks possible transmission; native errors
must retain ownership accounting for allocated resources.

ready supplies token, readable/writable/error and RX capacity (0–520).
Stale tokens are ignored; RX is limited to min(512,capacity).
Events prepared/tx_progress/tx_complete/rx/error/closed contain endpoint and a
copied token. service returns calls/bytes/clock_reads and event, not a growing
queue. Consume the event before servicing again. error ends attempt work;
closed is cleanup notification, not a second Modbus result. may_have_sent is
input to transport not_sent/unknown classification; adapter does not parse Modbus.

## Budgets and lifecycle

Four calls per endpoint/service including failures, at most 28 for seven endpoints.
The external dispatcher must service each endpoint only once per pass.
This module does not replace rounds or their eight-transition budget.
Clock reads are counted separately. Global poll/wakeup budget is one poll and
at most two wake operations per pass; dispatcher bounds notify calls.
Public IPC is not implemented.

EINTR/EAGAIN yield without retrying inside service. Setup/TX probes retry no
earlier than the next millisecond to prevent zero-time spinning; deadlines remain
unchanged. Zero write of a nonempty buffer is an error.
wait accepts 0–100 ms, capped by deadlines/retry; caller additionally caps by
scheduler quantum. No idle POLLOUT subscription. Future control IPC must join
the same poll; notify creates no background Lua thread and does not receive STOP.

Continue servicing after error/cancel to clean up. Do not retry close on the same
numeric fd after an error: Linux may already have released/reused it.
Dropping a live adapter is not cleanup. Scheduler retains assembly ownership;
integrated cleanup is still unverified.

Next: separately build/package the native dependency for target ABI, implement
single-call clock/poll/wakeup/termios/TX/close and verify actual bounds/size.
The script package still builds without SDK; dependency build is separate.
Then integrate with Lua states/scheduler using fake I/O and measure total RAM.
TC-134–138 have partial coverage; command-layer TC-139 remains planned.
No rover motor writes, networking or installed-core changes.

Stage 1.33 adds [isolated C primitives](NATIVE_IO.en.md) and host tests. Lua binding, target ABI and composition with this API remain pending.
