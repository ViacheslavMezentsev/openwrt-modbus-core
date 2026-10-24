# Schoolbell native adapter

[Русский](README.md)

Schoolbell specification 1.13: isolated Linux C player adapter and a test child without an audio device; 13 host process/fault groups, FD checks and inherited flock after owner death. No Lua binding, core, madplay/audio or router changes; IPK unchanged.

[API and limits](../../../docs/packages/schoolbell/LINUX_PLAYER.en.md).

`make -C packages/schoolbell/native` · `make test-schoolbell`
