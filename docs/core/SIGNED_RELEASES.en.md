# Signed release manifest and discovery API

[Русский](SIGNED_RELEASES.md) · [General contract](RELEASE_UPDATES.en.md)

26 October 2026. Contract: core specification 1.35 section 6.12 and schoolbell specification 1.55 section 4.8. The isolated host model is described below (core 1.36); real keys, cryptography, network and installation are not integrated.

## Assets, components and platform profiles

Publish IPKs and one `release-<profile>.json` / `release-<profile>.sig` pair per platform as **Assets of the same GitHub Release**, not on Pages. For example:

```text
modbus-schoolbell_5.1.2_all.ipk
modbus-rover_1.0.0_all.ipk
modbus-schoolbell-clock_1.0.0_mipsel_24kc.ipk
release-openwrt-19.07.9-ramips-mt76x8.json
release-openwrt-19.07.9-ramips-mt76x8.sig
```

This is an illustrative layout, not a published release. Normal asset names remain `<Package>_<Version>_<Architecture>.ipk`. Different bytes for the same version/architecture on different profiles use `<Package>_<Version>_<Architecture>.<profile>.ipk`, without changing internal control fields. The manifest supplies the exact asset name. Identical bytes may share one asset across profiles. Within a profile, changing bytes for the same package/version/architecture requires a new patch version.

One manifest contains multiple independently versioned components and lists shared dependencies once. Only the requested component and its dependency closure are selected. Old and new OpenWrt profiles can be maintained together. Missing older profiles in a newer release do not terminate the search or declare support ended. A profile identifies an exact registered platform/ABI set; filename alone proves nothing. Firmware changes invalidate earlier candidates and require profile selection again, without automatic migration. Version 1 supports IPK/opkg only.

Prefer one compatible Shkolnik application line across platforms. Application major versions do not encode OpenWrt versions; separate major lines remain possible when application compatibility actually changes.

## Signature and strict JSON

The manifest is UTF-8 without BOM, at most 65536 bytes including whitespace. **Pure Ed25519 (RFC 8032)** signs the exact file bytes: no Ed25519ph, SSH envelope or device-side reserialization/canonicalization. Changing a newline changes the signed message. The release producer generates reproducible bytes.

The signature file is JSON of at most 512 bytes with exactly three strings:

```json
{"algorithm":"ed25519","key_id":"<64 lowercase hex>","signature":"<128 lowercase hex>"}
```

These are placeholders. `key_id` is SHA-256 of the 32 raw public-key bytes; `signature` encodes 64 raw signature bytes. Only preinstalled keys scoped to repository/publisher are trusted. Unknown key/algorithm or invalid signature rejects the manifest. Key rotation/revocation requires a separate administrator procedure; verifier and trust-store delivery remain open. Do not implement cryptography from scratch.

Bound bytes, parse the signature, verify the raw manifest, then validate its schema. Both JSON documents reject duplicate/unknown fields, malformed UTF-8, BOM, NaN/Infinity. Maximum depth is 8. Integers are decimal 0..2147483647 without fractions/exponents; file lengths are positive. Strings contain no NUL/control characters. All fields below are mandatory; null is permitted only explicitly. String limits count UTF-8 bytes.

## Manifest v1

Root fields, and no others:

| Field | Contract |
| --- | --- |
| format | `openwrt-extension-release/1` |
| repository | registered owner/repo, at most 200 bytes |
| tag | exact release tag_name, at most 256 bytes; not the component version |
| source_commit | 40 lowercase hex Git SHA-1 |
| platform | object below |
| components | 1..64 component objects |
| packages | 1..64 package objects |

Platform fields: `profile` (1..96 ASCII `[a-z0-9][a-z0-9._-]*`), `package_format` (`ipk`), `openwrt` (up to 32), `target` (64), `architecture` (64), `libc` ({name,version}, up to 64 each), `lua` (ABI, up to 16), `kernel_abi` (up to 128 or null without kmods), `firmware` (up to 64 unique {name,version} built-in dependencies). Kmods require exact kernel ABI. Firmware dependencies are not replaced. Profile matches the JSON/signature filename; platform values are checked against verified local state, not browser input.

Component fields:

| Field | Contract |
| --- | --- |
| publisher, name | 1..64 ASCII `[A-Za-z0-9][A-Za-z0-9_-]*`, unique pair |
| package | root package name; components cannot share a root |
| version_scheme | `semver3` or `opkg` |
| upgrade_from | 1..16 nonoverlapping {min_inclusive,max_exclusive}; upper bound may be null |
| requires_core_api | supported identifier up to 64 bytes or null; unknown is incompatible |
| data_policy | {action,rollback}; preserve/migrate and package_only/restore_backup respectively |

Component version comes from its root package. Semver3 is three integers 0..2147483647 separated by dots, no leading zeroes except zero itself and no suffix/build metadata. Shkolnik uses semver3. Bounds use the declared comparison scheme and min < max. opkg versions are not compared as SemVer. A major transition needs an explicit upgrade interval and validated migration; signed metadata alone does not implement migration. Installing an absent component is outside this API.

Package fields:

| Field | Contract |
| --- | --- |
| name | unique Package, 1..128 ASCII `[a-z0-9][a-z0-9+.-]*` |
| version | opkg Version, 1..128 bytes |
| architecture | 1..64 bytes, all or compatible architecture |
| asset | unique basename, 1..192 ASCII `[A-Za-z0-9][A-Za-z0-9._+-]*`, ends in .ipk, no slash, backslash or `..` |
| bytes | positive integer IPK size |
| sha256 | 64 lowercase hex |
| depends | up to 64 {name,op,version}; any/eq/ge/gt/le/lt; any requires null version, others an opkg version string |

Firmware names/versions and dependency names use package field limits. The acyclic graph closes through packages or firmware, with disjoint names. Dependencies are conjunctive. Unsupported alternatives, virtual Provides or Conflicts are rejected, not simplified. Preparation verifies actual IPK control, normalized Depends, size and hash; discovery verifies signed metadata only, without downloading IPKs. Check reverse dependencies of **all installed packages** before changing a shared dependency. Conflicts are reported; no force or removal of unrelated modules. Manifests contain no shell commands, scripts or arbitrary download URLs; IPK hook admission is separate.

## Logical asynchronous API

These are logical operations, not chosen HTTP routes. `component` is a registered `publisher/name` string. Source, profile and trust store cannot be supplied by browser callers. Check/configure require administrator authorization and CSRF protection through the adapter; status requires authenticated read access. Wire transport and precise ACL remain open.

| Operation | Response and behavior |
| --- | --- |
| check(component) | immediate {accepted,operation_id,state,error}; start or join the same component's running check; another component gets busy, no queue |
| status(component) | stored snapshot, no network |
| configure(component,background_checks) | boolean input; {ok,background_checks,error}; disabling prevents future background attempts, current attempt may finish |

Operation IDs are 32 lowercase hex, not credentials. Accepted check: true/checking/null error; refusal: false/idle/null ID/error code. Configure success: ok=true/error=null; failure: ok=false/error code/previous policy. Repeated check does not duplicate a running operation. Restart does not blindly resume interrupted work.

Status fields: component; state (idle/checking/complete/failed); operation_id (32 hex/null); result (update_available/up_to_date/incompatible/incomplete/null); error (code/null); installed_version (string/null); candidate (object/null); scan_complete and fresh (booleans); age_seconds and retry_after_seconds (integer/null); background_checks (boolean); last_success (previous successful snapshot without a nested last_success, or null). Unknown component returns failed/unknown_component with unavailable values null and booleans false. No raw GitHub payload is exposed.

Candidate has exactly candidate_id, version, profile, manifest_sha256, repository, tag and signature_verified=true. Its ID is raw manifest SHA-256 + colon + component. It is bound to the component/profile/manifest and is not permission to install. Unverified metadata never becomes a candidate.

New checks clear current result/error/candidate, set checking/fresh=false/scan_complete=false and retain prior success separately. Before checking: idle/result=null. Failed attempts have result=null. Complete means the search algorithm finished, not installation. Incomplete always has scan_complete=false. A verified candidate from partial search may be update_available/scan_complete=false with the reason in error; do not call it the newest. Up_to_date requires complete, determinate search without newer compatible or incompatible variants; newer incompatible variants yield incompatible. No trusted component metadata gives incomplete/no_matching_manifest. Old or unrelated releases do not end the search; missing/broken potentially relevant metadata makes it incomplete.

Error codes: unknown_component, unauthorized, busy, network, dns, tls, clock_untrusted, rate_limited, timeout, response_too_large, invalid_manifest, unknown_key, bad_signature, release_conflict, unsupported_format, no_matching_manifest, incompatible_platform, dependency_conflict, internal. Backend mappings need dedicated tests.

Age is monotonic since attempt completion. Fresh requires complete, age below 86400 seconds, same boot/process and unchanged installed packages/profile/keys. New check or restart gives age=null; restart gives fresh=false. last_success ages are recalculated by the same rules, never represented as the current attempt's success. Untrusted UTC is not used for freshness.

## GitHub bounds

GET `/repos/{owner}/{repo}/releases?per_page=10`, follow Link next only for the same endpoint/repository, not /latest. Public access without PAT or LuCI cookies. Exclude draft/prerelease. Select the exact local profile pair and highest compatible component version, not repository release date/name. Validate API-provided asset sources.

| Limit | Value |
| --- | --- |
| Manifest / signature | 65536 / 512 bytes |
| Components / packages | 64 each |
| JSON depth | 8 |
| Release list | 3 pages of 10, at most 30 releases |
| List response | 262144 bytes |
| Entire attempt | 60000 monotonic milliseconds including DNS/TLS/redirects/metadata |
| Concurrency | one check, one HTTP request at a time |
| Background interval | at least 86400 seconds, no catch-up storm |

Bound actual bytes, not merely Content-Length. Request identity encoding; reject unexpected compression. Process metadata pairs sequentially and release memory. Up to 30 pairs may be read within the deadline. Remaining pages, timeouts, overflow or incomplete assets prohibit up_to_date. Do not retry failed HTTP calls inside an attempt; new attempts obey backoff. ETag/304 needs a complete bounded cache for the same URL with renewed validity checks; otherwise incomplete.

Never weaken HTTPS or change clocks/NTP/network. Exact CDN allowlist, redirect count, private/link-local/DNS-rebinding protections, HTTP backend, parser RAM and backoff under untrusted UTC remain prerequisites for a system downloader. Respect Retry-After/rate limits; manual checks cannot bypass them.

## Evidence and remaining work

Core TC-150–157 are planned: signature vectors/tampering, schema limits, multiple modules, platforms/reverse dependencies, API/repetition/ACL, bounded search/cache, asset/control identities, key/time/replay boundaries. RFC 8032 vectors are external oracles, not evidence that a target verifier passed.

No installer, key generation, rotation/revocation, anti-replay, persistent cache or wire transport is implemented. Verifier/HTTPS, ACL, RAM/tmpfs/flash budgets, redirect/backoff, exact opkg comparator and restart recovery remain open before system deployment.

Sources: [GitHub Releases](https://docs.github.com/en/rest/releases/releases), [REST practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api), [RFC 8032](https://www.rfc-editor.org/rfc/rfc8032).

## Isolated host model (specification 1.36)

Run `make test-release-discovery` (Python standard library only). It also runs in the core/all test runner. `scripts/release_manifest.py` validates exact bytes, signature envelope and schema, scopes a supplied trusted key, compares declared versions and resolves the selected dependency closure including installed reverse dependencies. `scripts/release_discovery.py` exposes check/status/configure plus cooperative step and trusted replace_context. All returned snapshots are copies.

Construct Discovery with registry, local snapshot, keys, fetch, monotonic millisecond clock, verifier and opkg comparator. The local snapshot includes platform, installed packages with complete dependencies, supported core_apis and explicitly approved migration tuples. This is trusted caller data, not browser input. The verifier takes public-key bytes, exact manifest bytes and signature bytes and must return exactly True. The opkg comparator returns -1/0/1; tests use synthetic numeric versions, not Debian/opkg semantics.

Fetch receives a Request(repository, kind, page/tag/asset, byte limit, absolute deadline); it returns Response(body bytes, status, next_page, encoding, error, retry_after_ms). Kind is list or asset; no IPK requests are issued. List bodies are GitHub-shaped JSON records; next_page is a normalized same-source pagination result. The model does not accept raw download URLs. A future transport must validate actual URLs/redirects/Link headers, enforce limits while streaming and meet the deadline. Checking a callback after return cannot interrupt a blocking real transport. Each step performs at most one supplied fetch; check and status perform none.

Missing profile pairs conservatively make the scan incomplete but do not stop older-release search. No HTTP cache is implemented: bare 304 never proves up-to-date. Network failures stop the attempt; schema/signature failures in individual pairs allow remaining search. A previously verified candidate can survive partial search with scan_complete=false; a conflicting reissue invalidates it. A signature verification completed after the deadline cannot publish a candidate. Backoff is repository-wide; simulated rate limits without a header use a 60-second model fallback, not an approved production backoff policy. Background scheduling is an explicit background check call, not a resident scheduler.

32 tests cover schema, signatures through a fake oracle, dependency conflicts, API state and scan boundaries. The fake signature is deliberately NOT Ed25519. No real cryptography, TLS, GitHub, system authentication, raw IPK inspection, installation or target memory bounds are certified. Authorization booleans model an already-checked caller; they are not an authentication implementation. State/cache is not persisted; constructing a new model starts idle. replace_context cancels pending work and invalidates candidates on package/platform/key changes. Persistent anti-replay and recovery remain open.
