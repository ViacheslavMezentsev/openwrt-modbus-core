# Native I/O primitives

[Русский](NATIVE_IO.md) · [Lua API](IO_ADAPTER_API.en.md) · [C API](../../native/io/omc_io.h)

Specification 1.33, 2026-10-24. An isolated Linux C layer, not a complete backend.
Lua binding, adapter/state/scheduler composition, target MIPS ABI verification and
native IPK delivery remain pending. Neither modbusd nor the script-only core IPK
loads or contains this library.

## Build and verification

```sh
make build-native-io
make test-native-io
```

The separate build produces `out/native-io/libomc-io.a`. It requires Linux headers,
a C99 compiler and ar; host tests also require coreutils timeout. Tests run in
`make all`/`make ci-core` and fail rather than skip if the compiler is missing.
The library build accepts CC/AR/CFLAGS/CPPFLAGS/BUILD; cross-building does not run
host tests. asm headers must come from the selected ABI sysroot. The script-only
`make build` still needs no OpenWrt SDK.

## Primitive boundary

| Group | Operation |
| --- | --- |
| clock | CLOCK_MONOTONIC in uint64_t integer milliseconds |
| open | Serial open with NONBLOCK/CLOEXEC/NOCTTY/NOFOLLOW; TCP socket and eventfd with NONBLOCK/CLOEXEC |
| prepare | Pure numeric IPv4/port and kernel 8N1 termios preparation |
| configure | One TCSETS ioctl; no tcgetattr/tcsetattr/tcdrain or flush |
| connect/status | One connect or readiness-triggered SO_ERROR getsockopt |
| RX/TX | One serial read/write or TCP recv/send; maximum 512/260 bytes |
| probes | TIOCOUTQ and TIOCSERGETLSR are separate calls |
| wait/wake | One poll, at most 8 fds and 0–100 ms; one eventfd write/read |
| close | Invalidate handle before one close; never retry the same fd |

Each `*_once` function invokes at most one libc system-call primitive; invalid
input invokes none. No EINTR/EAGAIN retries, transfer loops, DNS, implicit fcntl
or heap allocation. Clock may use vDSO. This bounds call count, not execution time.
Pure preparation is outside the syscall budget.

Errors return -1 with errno. Read/write return actual byte counts, preserving
short/zero I/O. TCP read zero means EOF; serial read zero with VMIN=0 alone is not
a disconnect. Read SO_ERROR only after suitable connect readiness; zero outside
that context is not proof of connection. MSG_DONTWAIT/MSG_NOSIGNAL prevents a
peer failure from terminating the process via SIGPIPE; see [send(2)](https://man7.org/linux/man-pages/man2/send.2.html).

errno values and API/termios structures are internal, ABI-dependent, never wire
formats. Do not mix asm/termbits.h kernel termios with libc termios.h in one
translation unit. Prepared 8N1 uses CLOCAL/CREAD, disables flow control, HUPCL,
transformations and echo; VMIN/VTIME=0 and equal RX/TX baud. Supported initial
rates: 1200/2400/4800/9600/19200/38400/57600/115200. B0/unknown rates are rejected;
this does not expand any device's allowed rate profile.

## Ownership and future composition

A trusted single-threaded caller owns buffers/handles, initializes handles with
OMC_HANDLE_INIT and never copies a live handle. External close, flag changes and
positive SO_LINGER are outside the ownership contract. Reopening a live handle
fails. fd zero is valid. Close invalidates even on EINTR/error because Linux may
reuse the number; see [close(2)](https://man7.org/linux/man-pages/man2/close.2.html).

Serial paths must already resolve to the intended trusted character device.
NOFOLLOW only protects the final component. USB resolution, path identity/races
and ownership verification are absent, blocking production integration. Setup
and optional verification must be separate accounted state-machine steps. No
hidden flush, exclusive lock or recovery has been added.

Poll borrows a descriptor snapshot; it stores no tokens and rejects no stale
generations. Discard revents on errors. The owner preserves the snapshot's
endpoint/connection/operation/attempt association and validates generations.
Eight entries allow seven endpoints plus wake, not the future public IPC.
Wake counts notifications; one drain reads the counter. Saturation EAGAIN means
notification is already pending, not permission to spin; see [eventfd(2)](https://man7.org/linux/man-pages/man2/eventfd.2.html).
The future Lua binding must restrict exact milliseconds to 2^53-1, normalize
errno and connect permit/deadline, token, four-call and wake budgets. C primitives
provide no Modbus write authorization, retry policy or STOP semantics.

## Evidence and limits

TC-142 linker wrappers inject EINTR/EAGAIN/EIO across all 17 operation paths,
checking exactly one invocation, unchanged output values on failure, short/zero
I/O, SO_ERROR, fd zero, duplicate open/close and input bounds.
TC-143 uses real loopback TCP connect/data/EOF/refusal, default SIGPIPE disposition,
binary raw PTY with termios readback, eventfd coalescing/saturation, signal-driven
poll EINTR, monotonicity and 200 FD cycles without leaks. External process timeout
protects the tests; it is not a runtime timing guarantee.

PTY reports ENOTTY for LSR. Empty driver queues do not prove wire completion;
LSR is driver evidence, not an automatic capability. The layer does not advertise
bounded_setup/bounded_close/rtu_tx_complete=true. Target libc/driver analysis,
MIPS build/delivery, bounded open/configure/close, TX evidence and total RAM/latency
remain pending. TC-134–138 remain partial; command-layer TC-139 is planned.
No hardware operation, runtime integration or rover authorization is added.
