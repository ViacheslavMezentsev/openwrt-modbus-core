# Addressing, gateways and extension settings

[Русский](GATEWAY_ARCHITECTURE.md) · [Core specification](TECHNICAL_SPECIFICATION.md)

## Accepted architecture; implementation pending

A logical device keeps its name independently of IP, tty and unit. For one TCP
endpoint gateway_a, room1_sensor maps external unit 11 to rs485_1/unit 1;
room2_sensor maps external unit 12 to rs485_2/unit 1. Duplicate internal IDs
work on separate lines, not on the same bus. Unknown routes are rejected without
broadcast probing. Exact UCI/API schemas remain open.

Direct mode uses core-owned ports and rounds, including Serial Monster.
An autonomous board owns downstream lines and routes without requiring a router
or a shared round barrier. Each RS-485 line has one transmitter owner, one active
RTU transaction and a bounded queue shared by incoming clients.

Roles: disabled, modbus-client (downstream requests), modbus-server (incoming
requests), monitor (receive only), bridge (forwarding), debug. Monitor/bridge
are later stages. Conflicting roles are rejected; filters cover units, functions,
registers, writes and request rates. A separate gateway specification and
management contract precede firmware implementation.

Modbus TCP is a core client transport; RNDIS is network connectivity. The initial
profile allows one outstanding operation per TCP connection. A router-side TCP
server or arbitrary proxy is not implicitly included.

The standard offline bundle must include kmod-mii, kmod-usb-net,
kmod-usb-net-cdc-ether, kmod-usb-net-rndis and missing dependencies for the exact
kernel ABI/platform. Keep separate IPKs, not .ko files inside the universal Lua
package. Admission checks integrity, trust and space; validate reboot offline.
Installation preserves LAN/IP/DNS/routes/firewall. Current make build does not
produce this bundle yet.

## Accepted user settings requirements

Separate configuration, user data and transient state:

| Content | Target location | Owner |
| --- | --- | --- |
| Settings/plans | `/etc/<package-id>/config.json` | Package |
| User media/data | Explicit persistent location, e.g. `/srv/<package-id>/` | Package/storage profile |
| Cache, PID, active queues | `/tmp/<package-id>/` | Package runtime |
| Factory resources | `/usr/share/<package-id>/` | Package distribution |

The architecture is accepted in specification 1.16 section 6.6; implementation is absent. /var on OpenWrt is generally not
persistent; /srv without external storage consumes overlay. Check actual storage
and capacity. Do not write frequent telemetry/queue updates to flash. Uploaded
JSON must not choose destination filesystem paths.

Packages own schemas, semantic validation, migrations and activation. The
shared mechanism must provide bounded JSON reads, an envelope (package_id,
schema_version, config_revision, payload), size checks, same-filesystem staging,
write verification and replacement. Lua 5.1 has no built-in JSON; the project
uses luci.jsonc as an explicit dependency. Function names/schema remain open.

Import: parse without executing code; check package/version/limits; invoke package
validation/migration; preview changes; save/activate under the package contract.
Invalid input preserves the active configuration. Single-file rename does not
prove power-loss durability or multi-file atomicity; write failures, fsync,
rollback and activation need a separate design. conffiles is not a backup.

Distinguish a fleet template (shared plans/settings without network addresses,
hardware identities or secrets; validate local logical-device bindings) from a
device backup (versions, settings and a user-file manifest, with explicit secret
handling). Media stays outside ordinary JSON, referenced by media ID/revision.
Moving files needs a bounded archive and integrity/space checks. Fleet import
must not silently play audio or change networking: stage/validate before explicit
activation.

Planned acceptance cases TC-93–100: export/import round-trip, wrong package/version,
malformed/oversized JSON, missing media, incompatible migration, ENOSPC/power
failure, and applying one template to two devices without cloning unique bindings.
Schoolbell retains its own backup/restore requirements; a helper may support but
does not replace them. No helper is implemented in this stage.
