# Schoolbell clock trust

[Русский](CLOCK_TRUST.md)

Accepted requirements in schoolbell specification 1.31, section 4.7. **Documentation only:** schoolbell 5.0.14 gains no implementation; firmware, services, clocks and NTP remain unchanged. TC-113–119 are planned acceptance cases, not passing tests.

| State | Meaning | Automatic ringing |
| --- | --- | --- |
| Unconfirmed | New boot, no usable evidence or observation context | Blocked |
| Rollback detected | UTC earlier than the saved confirmed timestamp by more than 5 s | Blocked |
| Confirmed | Evidence accepted with an identified source | Separate explicit enable allowed |
| Review required | Clock step, observation failure or exceeded agreed uncertainty | Blocked |

A saved timestamp is a lower reference, not downtime measurement or restored trust. UTC later than that timestamp does not establish accuracy. During continuous observation compare UTC elapsed time with monotonic elapsed time. A step strictly greater than 5 s in either direction requires review; equality does not trigger. Thresholds are configurable, but ranges and sampling/error budgets remain open. A DST change in displayed local time is not a UTC step.

First implementation stage: durable reference/source/checksum, states, server-side admission gate and explicit manual verification. Confirming the displayed clock is separate from enabling the plan. Browser time is only an aid. Failed persistence or stale context cannot succeed. Replacing a mistakenly future reference requires explicit acknowledgement; the consumed-event watermark is never lowered. Automatic network confirmation and RTC checks follow separately after source-quality criteria are agreed.

Loss of trust blocks new automatic bells/pre-bells and invalidates the previous enable. Already admitted audio may finish; Mute still applies. Manual ringing remains available under normal player restrictions. Reconfirmation does not re-enable anything or replay missed events. The executor checks trust at final admission, not merely at the UI button.

The duty panel shows state, reason, source and confirmation date; bounded logging records transitions/actions, not every poll. Plan years remain independent of the clock; missing years are quiet. Plan years never set the clock. Backup/fleet transfer does not carry device-specific reference, trust or enable permission.

Open: record format/migration; checkpoint period/flash wear; threshold ranges; observation/freshness budgets; NTP/RTC quality; allowable uncertainty and autonomous trust duration. Five seconds is a detection threshold, not promised bell accuracy. A one-day passive measurement cannot guarantee year-long accuracy. No core API is added by this package contract.
