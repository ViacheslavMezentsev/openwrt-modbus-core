# rover package

[Русский](README.md) · [Specification 1.0](TECHNICAL_SPECIFICATION.md) · [CHANGELOG](CHANGELOG.en.md)

A separate example: wheeled rover with router, USB webcam, Arduino-compatible
board, motor drivers and battery. A phone/tablet browser connects over the
router's local Wi-Fi without Internet; controls overlay the video.

Two bases: two driven wheels plus one support wheel, or four driven wheels.
Differential speed steering, no steering servos. RTU/TCP goes through the core;
video, UI and mixing belong to rover.

Requirements draft only, no IPK/firmware. Proposed policies: one controlling
session, hold-to-drive, STOP, stale-command rejection, board watchdog and stop
on video loss. Timings and safe driver state require agreement.

Separate stages: safety/board contract → fake-I/O mixer/sessions →
isolated UI/video and measurements → approved core writes →
offline bundle/settings → separately authorized motor bench.
Power checks and lifted wheels first; driving on the ground is a separate test.
mr3020-modes/administrator prepares Wi-Fi explicitly; installation does not
silently change networking.

Separate requirements/history support later repository extraction.
Core 1.30 is an architectural baseline, not a released public API version.
