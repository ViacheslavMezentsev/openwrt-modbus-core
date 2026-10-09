# Schoolbell package

[Русский](README.md)

School calendar, bells and melodies. The package registers schedules/subscriptions with core; the new port is not implemented yet.

[ТЗ 1.3](TECHNICAL_SPECIFICATION.md) · [CHANGELOG](CHANGELOG.en.md)

The specification remains a draft. Requirement/test IDs belong to this component;
qualify references with `core`, `demo` or `schoolbell`. A specification revision
is not an API version. The root changelog retains pre-split history; future
component changes belong here and in its specification. Research remains local.

## Sample preview package

`make build-schoolbell` creates `out/modbus-schoolbell_0.0.1_all.ipk`;
its independent version is set with `SCHOOLBELL_VERSION`. It is part of `make all`.
This is a media-only preview containing `/usr/share/modbus-schoolbell/melodies/test.mp3`
and NOTICE, with no service, cron, player, configuration, or automatic sound.
The functional port will declare its future core API dependency; no compatibility
with that API is claimed now.

[Original media](../../../packages/schoolbell/media/README.en.md): six MP3s;
only the shortest test.mp3 (about 3.28 s, 13104 bytes) is bundled. CI verifies
the manifest and exact IPK payload using Python 3.8+ on the build host.
The preview package has not been installed. The owner confirmed manual MP3
playback with madplay; this does not validate the functional package.

For the first experiment, connect speakers at minimum volume, then inspect
player availability, the audio device and USB power. After separate agreement,
play the short file once and remove temporary files. Building the IPK does not
install a player, alter mixer/drivers, or produce sound.

Specification 1.3 owns audio execution, FIFO/expiry/cancellation transferred from core, with offline dependencies and persistent storage. Manual playback is confirmed; the functional package is not implemented.
