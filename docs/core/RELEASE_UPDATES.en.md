# Extension release checks and managed updates

[Русский](RELEASE_UPDATES.md)

26 October 2026. **Requirements only; not implemented.** Normative ownership: [core specification](TECHNICAL_SPECIFICATION.md), section 6.11, revision 1.35; Shkolnik UI: [package specification](../packages/schoolbell/TECHNICAL_SPECIFICATION.md), section 4.8, revision 1.55.

## User journey

A small notification identifies a verified compatible update; an unverified release is labelled separately. Settings → Update shows versions, changes, compatibility, space and last-check state. Users can check manually or disable background notifications. Offline operation continues normally.

An administrator chooses Prepare Update, reviews dependencies, space, backup and recovery, then separately confirms Install Update. Merely checking, downloading or opening a page never installs. The UI uses a shared extension service instead of duplicating installation logic. After a connection loss it retrieves the existing operation result rather than repeating installation. Shkolnik requires automatic bells off and remains off afterwards.

## Identity and compatibility

| Entity | Value |
| --- | --- |
| Display name | Shkolnik, without a version suffix |
| Extension identity | publisher `ViacheslavMezentsev`, name `schoolbell` |
| opkg Package | `modbus-schoolbell` |
| Application version | `major.minor.patch`, numerical tuple comparison |
| IPK | `modbus-schoolbell_<version>_all.ipk` |
| Native dependency | `modbus-schoolbell-clock`, independently versioned/architectured |
| Repository | public Releases of `ViacheslavMezentsev/openwrt-modbus-core` |

This is a future package.json identity mapping, not an installed manifest change. Existing IPK names remain. A repository release can contain several independently versioned components, so its tag or `/releases/latest` is not a package version. Other extensions need an explicitly supported version grammar; opkg dependencies keep their own grammar. Changed bytes require a new application patch version.

A signed release manifest binds component/version, source/release identity, platform and API profile, dependency constraints and exact resolved artifacts, sizes/SHA256, migrations and rollback compatibility. Its strict schema, exact-byte Ed25519 signature and logical API are specified in SIGNED_RELEASES.en.md; key delivery/rotation and system mechanisms remain open in core 9.2.31. The existing `format:1` offline build manifest is not yet this signed update contract.

Current target: OpenWrt 19.07.9, ramips/mt76x8, mipsel_24kc, musl and Lua 5.1, with exact firmware/kernel ABI verified separately. `all` does not make native dependencies portable. Already compatible dependencies stay installed. Missing dependencies and recovery files are staged before installation; subsequent network access is not required. Firmware, libc, network and core updates are not silently added to an application update.

## Trust, resources and recovery

Public GitHub Releases are checked over verified HTTPS without a user token or HTML scraping. Drafts/prereleases are excluded from the ordinary channel. An incomplete bounded scan cannot report “up to date”. One check runs at a time; background attempts are at least 86400 monotonic seconds apart, with no catch-up burst. They do not download IPKs. Cache/ETag, Retry-After and rate limits are honoured; manual requests do not bypass backoff. Detailed time/JSON/pagination/RAM/storage limits and initial-check behaviour must be specified before implementation.

Trusted signing keys come from outside the downloaded release. HTTPS, checksums, GitHub asset digests and signed commits are not substitutes for signed release metadata. Unknown keys, incompatible ABI/data, unsupported mandatory fields, unsafe paths or insufficient peak space prevent installation. Invalid clock/CA/TLS states remain explicit errors: the checker never changes time/NTP or weakens TLS to continue. Local verified-bundle import remains a separate fallback; no inbound webhook/network opening is required.

Server-side administrator authorization, request protection, a single operation owner and a confirmation bound to exact hashes/dependencies/source revisions are required. Changed conditions invalidate confirmation. Backups, compatible previous packages, post-install verification and a downloadable external recovery copy are mandatory; the external-copy acknowledgement mechanism remains open. Older code may require restoring older data, not stripping unknown fields.

opkg plus backup does not provide atomic power-loss rollback. Interrupted installation blocks activation until recovery is verified; external recovery may be necessary. Unattended installation, automatic reboot and firmware/network/time changes are outside this stage. Packages declare readiness constraints; Shkolnik blocks updates during sound, automatic bells, media/backup operations and unsaved local edits, while stale edits from other tabs retain CAS/version protection.

## Implementation sequence and evidence

1. Follow [the concrete manifest/API](SIGNED_RELEASES.en.md) for isolated modeling; settle verifier/key delivery, HTTPS, wire/ACL and system resource budgets before network integration.
2. Isolated discovery with fake network and version/compatibility/error cases.
3. Shkolnik notification/check UI; Pages only simulates states.
4. Isolated admission, staging, operation and recovery fault tests.
5. Explicitly authorized installation after target-profile acceptance.

Core TC-144–149 and schoolbell TC-146–149 are planned, not passing tests. This branch validates documentation only; runtime/IPK/router state is unchanged.

## Official references

- [GitHub Releases API](https://docs.github.com/en/rest/releases/releases): public releases may be queried without authentication; draft/prerelease and asset metadata are exposed.
- [REST API best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api): conditional requests, redirects and rate-limit handling. Our token-free profile does not assume anonymous 304 responses are quota-free.

[Concrete signed format, platform-specific asset names and multiple modules](SIGNED_RELEASES.en.md).
