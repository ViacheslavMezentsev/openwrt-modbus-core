# openwrt-modbus-core

Лёгкий фундамент для Modbus-ядра под OpenWrt без OpenWrt SDK и без локальной сборки прошивки.

## Что уже заложено

- Скриптовый пакет `modbus-rtu-core` в формате `.ipk`
- Базовый демон `modbusd` с инициализацией runtime-директории и health-состояния
- UCI-конфиг, `procd`-инициализация и web-страница статуса
- Лёгкая сборка `.ipk` через `tar`
- Быстрый деплой на роутер по SSH без `opkg install`
- Локальные smoke-тесты и верификация структуры пакета

## Принципы

- Без OpenWrt SDK: проект скриптовый, поэтому пакет собирается напрямую
- С минимальной нагрузкой на машину разработки: только `sh`, `tar`, `ar`, `make`
- С фокусом на фундамент ядра: без привязки к BluePill на текущем этапе

## Основные команды

```bash
make build
make build-demo
make test
make verify
make deploy-core
make deploy-demo
make install-ipk
make test-opkg
make router-clean
make repo
```

Полный локальный путь валидации, включая контрольные суммы артефактов:

```bash
make all
```

`make all` запускает Lua-тесты, если установлен `lua5.1`. На минимальном WSL
хосте он всё равно собирает пакеты и проверяет shell-скрипты и содержимое
пакетов; те же Lua-тесты обязательно выполняются в GitHub Actions.

Ядро хранит события в `/tmp/modbus/events-core.jsonl`; UCI-опция
`event_log_max_bytes` ограничивает каждый из двух сегментов журнала. По
умолчанию это `65536` байт для текущего файла и одного предыдущего сегмента.

`make router-clean` очищает временные списки `opkg` и загруженные `.ipk` на роутере после тестовых установок.
`make install-ipk` устанавливает собранные `.ipk` на роутер через `opkg`.
`make test-opkg` прогоняет полный lifecycle-test: unmanaged cleanup, install, verify и cleanup.
`make test-core-demo-router` устанавливает оба пакета, отправляет контрольное
событие из ядра и проверяет, что `modbus-demo` получил его через CGI.

## Demo module

`pkg-demo` is the first test subscriber module. It consumes core events from
`/tmp/modbus/events-core.jsonl`, keeps its own status file in `/tmp/modbus`,
and exposes a tiny UI through `uhttpd`.

## BluePill firmware prototype

The first USB CDC Modbus RTU server for STM32F103CB is in
[`firmware/bluepill-modbus`](firmware/bluepill-modbus). It is flashed on a
laptop for initial bring-up, then connected to the router as `/dev/ttyACM0`.
The core-side Modbus polling transport is the next implementation stage.

## Примечание по железу

Текущий каркас не общается с `ttyACM0` и не реализует Modbus-обмен с BluePill. Это сознательно отложено до появления отдельного проекта/протокола для STM32-устройства.
