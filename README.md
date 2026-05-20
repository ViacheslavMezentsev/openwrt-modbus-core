# openwrt-modbus-core

Лёгкий фундамент для Modbus-ядра под OpenWrt без OpenWrt SDK и без локальной сборки прошивки.

## Что уже заложено

- Скриптовый пакет `modbus-rtu-core` в формате `.ipk`
- Базовый демон `modbusd` с инициализацией runtime-директории и health-состояния
- UCI-конфиг, `procd`-инициализация и web-страница статуса
- Лёгкая сборка `.ipk` через `tar` + `ar`
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

`make router-clean` очищает временные списки `opkg` и загруженные `.ipk` на роутере после тестовых установок.
`make install-ipk` устанавливает собранные `.ipk` на роутер через `opkg`.
`make test-opkg` прогоняет полный lifecycle-test: unmanaged cleanup, install, verify и cleanup.

## Demo module

`pkg-demo` is the first test subscriber module. It consumes core events from
`/tmp/modbus/events-core.jsonl`, keeps its own status file in `/tmp/modbus`,
and exposes a tiny UI through `uhttpd`.

## Примечание по железу

Текущий каркас не общается с `ttyACM0` и не реализует Modbus-обмен с BluePill. Это сознательно отложено до появления отдельного проекта/протокола для STM32-устройства.
