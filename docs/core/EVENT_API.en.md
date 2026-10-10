# Event API: accepted v1 profile

[Русский](EVENT_API.md) · [Core specification 1.10](TECHNICAL_SPECIFICATION.md)

This is the accepted profile design before implementation, not a released API
in core 0.4.0. Normative requirements: core 4.5.17–4.5.24. Quotas, exact field
types/errors, codec and SDK signatures must be finalized before implementation.

## Connection and messages

Local Unix stream at `<runtime_dir>/events-v1.sock`, socket mode 0600 inside a
protected directory. UTF-8 JSON object plus LF; hello negotiates api=1 and owner.
One channel per owner; a second receives owner_busy. The first profile trusts
local administrator-managed packages: owner is logical ownership, not a sandbox
between root processes. Web users go through the package backend.

| Operation | Main request fields | Response meaning |
| --- | --- | --- |
| hello | api, owner | api, instance_id, session_id, limits |
| status | request_id | Own revision/generation, state and bounded error counters |
| replace | request_id, expected_generation, revision, definitions[], subscriptions[] | Confirmed generation of the complete set, or rejection preserving the old set |
| unregister | request_id, expected_generation | Empty set; a stale command cannot remove a newer registration |
| publish | request_id, topic, schema_version, payload, correlation_id? | accepted + event_id, or rejection before acceptance |
| ack | request_id, instance_id, event_id, subscription_id, registration_generation | Adapter receipt, not application completion |

Definitions contain topic/schema_version; subscriptions contain id/topic. Packages
publish only their own declared `/packages/<owner>/...` types; `/core` and
`/devices` belong to core. Exact topic subscriptions have no wildcards and may
wait for a type not yet declared. Two subscription IDs receive separate notifications.

Envelope: instance_id, event_id, topic, schema_version, publisher, mono,
utc or null, clock_valid, payload; notifications also carry subscription_id and
registration_generation. Instance changes on every core process start; event ID
is not the JSONL sequence. Request ID correlates a command/response; correlation ID
links a result to its source event. Identifier formats remain to be finalized.

## Registration and delivery

Replace validates the entire set before applying it. The same revision and
structurally identical content return the existing generation; changed content
under the same revision conflicts. A new revision requires current expected_generation.
Dispatch retains its snapshot; an old-generation notification can arrive after
the replace response. Clients distinguish generations.

Registrations belong to the session. Disconnect removes them at the snapshot
boundary and clears pending deliveries, without cancelling actions already
accepted by the client. Reconnect explicitly reconciles instance/generation and
restores the set. Calendar moments are a later scheduler extension, outside P01.

Delivery is live, with no automatic replay after reconnect/reboot. One logical
send per session; partial writes continue it rather than create another delivery.
Accepted means queued, ack means received, a separate client event reports the
application result. A lost publish response is uncertain: SDK does not silently
retry. Exactly-once and power-loss queue durability are not promised.

A full global queue returns busy before accepted, without event_id. A full client
output queue disconnects only that client and increments diagnostics; an overflow
message cannot be guaranteed on that channel. Other clients continue. Pending
acks are bounded by count/time; expiry does not trigger replay.

## Client adapter

One package process handles multiple callbacks, each with its own payload copy.
An exception disables only that callback until an explicit successful reload;
its unconfirmed publications are discarded, external application effects are not
rolled back. Reconnect alone does not repair a disabled callback. Audio, melody
queues and results belong to schoolbell; core has no play/stop methods. Long
client work must not block other packages or polling.

## Next checks

TC-61–66 cover handshake, namespaces, atomic/repeated registration, generations,
disconnect, uncertain publish, overflow/acks, framing and bounded work. The codec
must enforce pre-decode frame bounds, JSON depth/elements, finite numbers, UTF-8
and distinct empty objects/arrays. Research values are not an agreed MR3020 budget.

Existing synchronous RTU and long modbusd sleeps still constrain IPC. Requirements
6.2.4–6.2.7 add configurable bounded safe-read retries and IPC servicing during waits.
Section 4.7 batches compatible same-unit/function reads without unknown addresses
or deadline violations. These features are not implemented; the 500 ms timeout
(range 100–2000) already exists, retry count does not.
