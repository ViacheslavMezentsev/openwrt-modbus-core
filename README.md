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

## Topic diagnostics

```sh
modbus topics
modbus echo /devices/1/sample --count 5 --duration 40
modbus hz /devices/1/sample --duration 30
```

Run these commands on the router. `topics` lists registered sources, age of the
last publication and state; `echo` follows new JSON messages; `hz` reports the
frequency and mean interval of new publications, not changes in values.
`echo` without limits and `hz` without a duration run until Ctrl-C. Unknown
topics/options are errors. If no new message arrives, `--duration` still exits.

The core publishes `/core/heartbeat`, `/devices/1/sample` and
`/devices/1/status` (replace `1` with the configured unit ID). Status is emitted
on startup and transitions, including errors/recovery, not on a fixed schedule.
The device topics are registered only when the BluePill profile is enabled.
Sample arrays use offset 0 as their first element, as in demo events.

Registry `topics.json` and the two event-log segments stay in the configured
runtime directory (`/tmp/modbus` by default). Commands read them without opening
the serial port or starting extra daemons. `MODBUS_RUNTIME_DIR` overrides the
UCI path for diagnostics/tests. Journal gaps or sequence reset produce a stderr
warning and reset the hz measurement window. Only retained events can be read:
slow subscribers may miss events after two segments are overwritten.
Publication intervals use kernel uptime, independent of wall-clock/RTC changes.
`hz` needs two new publications to estimate rate; `age_s` keeps increasing when
publishing stops. `topics` marks stale samples and an expired core heartbeat.

See [TODO.md](TODO.md) for RTC, serial gateway and firmware-update plans.

From WSL, `make test-topics-router` verifies live echo/rate output and an
isolated journal-rotation scenario on the router (default BluePill unit 1).

## Demo module

`pkg-demo` is the first test subscriber module. It consumes core events from
`/tmp/modbus/events-core.jsonl`, keeps its own status file in `/tmp/modbus`,
and exposes a tiny UI through `uhttpd`.

## BluePill firmware prototype

### Router polling

The `bluepill` profile reads DI (FC02, 0..1), AI (FC04, 0..4),
DO readback (FC01, 0..1) and PWM setpoint (FC03, 0) every poll interval.
Only one process may own the serial port. Close serial monitors before enabling.
The transport requires `luci-lib-nixio` and a `stty` supporting `-F` (present
on the development router). Enable after verifying the USB port:

```sh
uci set modbus-rtu-core.main.profile=bluepill
uci set modbus-rtu-core.main.device=/dev/ttyACM0
uci set modbus-rtu-core.main.baudrate=115200
uci set modbus-rtu-core.main.parity=N
uci set modbus-rtu-core.main.unit_id=1
uci set modbus-rtu-core.main.request_timeout_ms=500
uci commit modbus-rtu-core
/etc/init.d/modbus-rtu-core restart
```

The cache contains `devices["1"].di/ai/do/ao`, with zero-based register keys.
`meta.data_valid` describes the complete last poll; when offline, retained
values are stale and `meta.last_success` identifies their age. A failed request
ends that poll; the next poll reopens the port. Each response is checked for
length, unit, function, exceptions and CRC. `device_sample` events carry the
same values to demo. Register writes and USB stable naming are separate steps.
The profile defaults to `none`, preserving the router-only demo workflow.

`make test-bluepill-router` checks matching fresh samples in core and demo CGI
without installing packages or opening the serial device. It runs through WSL
with a 60-second overall timeout. First stop polling (`profile=none` and restart
the service) before using separate serial diagnostic tools.

The first USB CDC Modbus RTU server for STM32F103CB is in
[`firmware/bluepill-modbus`](firmware/bluepill-modbus). It is flashed on a
laptop for initial bring-up, then connected to the router as `/dev/ttyACM0`.
The `bluepill` profile polls this register map; output writes are a subsequent stage.

## Примечание по железу

Текущий каркас не общается с `ttyACM0` и не реализует Modbus-обмен с BluePill. Это сознательно отложено до появления отдельного проекта/протокола для STM32-устройства.
