# RAW/NTP method

The probe brackets UDP send/receive with CLOCK_MONOTONIC_RAW. Server transmit T3
causally lies inside that bracket; no symmetric network delay is assumed. SSH launch
latency is outside it. Split boot/clocksource epochs and keep each server separate.
Verify NTP length/version/mode, LI, stratum, originate, T2/T3 ordering and era.
The example supports era 0 only, until February 2036. Connected UDP is not authentication.

Conditional server uncertainty is E=abs(root_delay)/2+root_dispersion+2**precision+
server_margin. The pilot used 1 ms server margin and 10 us local allowance per sample;
these are engineering assumptions, not measured hard bounds or a full RFC clock filter.
For another device justify them again. Timer resolution is not frequency accuracy.

For A/B: D=T3_B-T3_A, E=E_A+E_B,
L=RAWlo_B-RAWhi_A-2*l, H=RAWhi_B-RAWlo_A+2*l.
Require D>E, L>0 and H>=L. The conditional rate interval is
[1e6*(L/(D+E)-1), 1e6*(H/(D-E)-1)]. Positive means RAW runs fast.
Compare whole-run, half-run and shorter windows per source. Do not average conflicting
intervals or call their midpoint a confidence estimate. Preserve all errors and gaps.

For ppm [a,b], the constant inverse scale lies in
[1/(1+b/1e6),1/(1+a/1e6)]. This is not an instruction to write adjtimex. Its modes=0
frequency is read-only controller state, not an independent rate measurement;
TIME_ERROR is not a measured large UTC error. Never double-correct working NTP.

This probe lacks T4 REALTIME and a measured initial UTC/RAW pairing bracket. It cannot
bound absolute UTC synchronization accuracy. A separate experiment needs actual
T1/T4 and paired UTC/MONO/RAW brackets, detecting corrections and steps. See
[RFC 5905](https://www.rfc-editor.org/rfc/rfc5905),
[clock_gettime](https://man7.org/linux/man-pages/man2/clock_gettime.2.html) and
[adjtimex](https://man7.org/linux/man-pages/man2/adjtimex.2.html).

Run `python3 scripts/analyze.py --self-test`, cross-compile probe.c for the target,
verify ABI/SHA, and deploy only within an authorized isolated experiment. Save a local
baseline (boot, clocksource, NTP configuration/processes, hashes). No time/NTP/service
changes. Start collect.py with --host, --probe, --sha256, two --server arguments and a
new --out directory. Defaults 300 seconds/289 samples span 24 hours. It verifies probe
SHA and records run/status/samples; it does not install or clean up. Do not restart a
completed run or catch up missed samples. Analyze with `analyze.py samples.jsonl`.

JSONL rows contain seq, host_utc, ok and peers; peer fields include server, ip, valid,
boot, raw_lo/raw_hi, request/response hex or error. Analysis re-decodes packets and
separates server/epoch. Verify expected count, seq, intervals and baseline independently.
Store hardware data locally, outside Git. After completion remove only the owned probe
with matching hash and its empty directory. One day cannot guarantee annual accuracy:
temperature, load, supply, aging and initial error need separate budgets and testing.
