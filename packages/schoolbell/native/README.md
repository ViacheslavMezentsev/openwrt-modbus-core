# Нативный адаптер schoolbell

[English](README.en.md)

ТЗ schoolbell 1.13: изолированный Linux C-адаптер проигрывателя и тестовый ребёнок без аудиоустройства; 13 host-групп процессов/отказов, FD и наследование flock после аварии владельца. Без Lua binding, ядра, madplay/звука и изменений роутера; IPK прежний.

[API и ограничения](../../../docs/packages/schoolbell/LINUX_PLAYER.md).

`make -C packages/schoolbell/native` · `make test-schoolbell`
