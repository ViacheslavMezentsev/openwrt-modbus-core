# Isolated transport states

[Русский](TRANSPORT_STATES.md) · [Accepted contract](TRANSPORT_CONTRACT.en.md)

Run `python3 scripts/test_transport_states.py`: 37 deterministic tests, also in
`make all` and `make ci-core`. [Model](../../scripts/transport_states.py) and
[tests](../../scripts/test_transport_states.py) are host-only Python, like the
previous rounds model. They add no router dependency and are excluded from IPKs.
No socket/serial, sleep, OS clock, UCI, Lua backend, queue, grouping, round executor
or modbusd integration is implemented. Passing the model is not hardware evidence.

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

Tests advance time between events. Methods do finite work, but the global limit of
8 transitions/512 bytes per pass, endpoint fairness and IPC servicing need the next
scheduler composition stage.

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

TC-116/117/118/119/122 remain planned for the new implementation: UCI, compatibility,
hotplug binding, queues, grouping and composed rounds are absent. The previous 16
rounds tests retain their abstract-only scope.

Next: compose these states with host scheduling, early results, the RTU barrier and
independent TCP. Then implement the production Lua/backend boundary with fake I/O.
modbusd integration and hardware experiments remain separate stages.
