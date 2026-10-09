# openwrt-modbus-core

[English](README.en.md)

Лёгкое Lua-ядро автоматизации для OpenWrt с Modbus RTU, кэшем, событиями
и пользовательскими обработчиками. Скриптовые `.ipk` собираются без OpenWrt SDK.

## Текущее состояние

- Ядро 0.4.0: UCI/procd, CGI состояния, ограниченный журнал в `/tmp`.
- Demo работает на одном роутере; профиль BluePill добавляет USB RTU-опрос DI/DO/AI/PWM.
- `modbus topics`, `echo`, `hz` показывают публикации без открытия serial-порта.
- WeAct BluePill Plus v1.1 STM32F103C8T6: PA0 - кнопка, PB2 - системный LED.
- Карта v2 и Lua-сценарий: счётчик нажатий -> событие -> абсолютная FC05-запись LED -> readback.
- Arduino CLI собирает приложение Maple DFU с проверкой `0x08002000` и лимита 56 КиБ.

Проверенное окружение: WSL Ubuntu-20.04, OpenWrt 19.07.9 на MR3020 v3,
kernel 4.14.267, Lua 5.1. USB CDC не является электрическим RS-485.
RTC и шлюз RS-485 пока в плане; общие DO/PWM-команды ядра ещё не разрешены.

## Сборка и проверки

В WSL из корня репозитория:

```sh
make all
sh scripts/build-bluepill.sh
sh scripts/test-handlers-router.sh
make test-bluepill-router
make test-topics-router
```

Последние три команды требуют SSH-доступа к роутеру (`ROUTER_HOST`, по умолчанию
`openwrt`). Тест обработчиков изолирован и не открывает живой USB. Остальные
проверяют работающую систему. Без локального Lua его тесты в `make all`
пропускаются; это не PASS. В CI Lua устанавливается явно.
В локальный набор входят проверки TTL команд, несовместимой карты, ошибок readback,
снимков/лимитов Lua и граничных размеров журнала; оборудование им не требуется.

`make build`, `make build-demo`, `make verify`, `make repo` управляют артефактами.
`make install-ipk`, `make test-opkg`, `make test-core-demo-router` меняют состояние
роутера: перед запуском согласуйте воздействие и резервную копию конфигурации.
`make deploy-core`/`make deploy-demo` - прежний unmanaged-деплой, не основной
путь поверх opkg. `make router-clean` удаляет временные IPK и кэш; сначала
убедитесь, что они не нужны другому процессу.

## Работа на роутере

```sh
modbus topics
modbus echo /devices/1/sample --count 5 --duration 40
modbus hz /devices/1/sample --duration 30
modbus echo /devices/1/system/commands --duration 30
```

Замените `1` на UCI unit_id. По умолчанию `profile=none`, системные обработчики
выключены. Настройка профиля и карты: [прошивка](firmware/bluepill-modbus/README.md).
Включение сценария и API Lua: [события](firmware/bluepill-modbus/ROUTER_EVENTS.md).
Эти существующие технические памятки пока на английском.

После проверки порта и согласования изменения UCI профиль включается так:

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

Для сценария кнопки дополнительно включите `system_events` по памятке событий.

Кэш использует нулевые адреса; `meta.data_valid` характеризует последний полный
опрос, `meta.last_success` - его время. При потере связи старые значения не
считаются актуальными. Системные топики публикуются по изменениям; их age/hz
описывают события, а не частоту USB-опроса. После переподключения старые нажатия
не воспроизводятся. Единственный владелец serial - `modbusd`.

Журнал: `/tmp/modbus/events-core.jsonl` и `.1`, лимит по 65536 байт,
настройка `event_log_max_bytes`. JSONL-запись сверх лимита (вместе с LF) отклоняется
до ротации с явной ошибкой, без обрезания JSON и изменения журнала или seq.
Лимит файлов не является лимитом памяти сериализации; старые файлы при уменьшении
настройки требуют отдельной проверки. Медленный подписчик может потерять вытесненные
события; CLI предупреждает о разрыве. Монотонные интервалы не зависят от RTC/NTP.
`MODBUS_RUNTIME_DIR` переопределяет каталог диагностики/тестов.

## Разработка

[Правила](AGENTS.md), [рабочий цикл и ТЗ](docs/DEVELOPMENT.md),
[план](TODO.md), [история](CHANGELOG.md).
Русское [ТЗ, ревизия 1.8](docs/core/TECHNICAL_SPECIFICATION.md) находится в статусе
черновика для согласования: требования связаны с кодом и тестами, пробелы отмечены явно.
Push и land выполняет владелец; land только после успешного CI текущей ветки.
Новые PR не требуются. Исследовательские материалы остаются локальными.

Итоги стендовых проверок, ограничения и порядок обновления/отката:
[памятка проверок](docs/VALIDATION.md).

Навигация по документации и архиву: [docs](docs/README.md).

Пример schoolbell: `make build-schoolbell` (также входит в `make all`).
[Состояние пакета](docs/packages/schoolbell/README.md): scheduler/player ещё нет.
Для проверки сборки на хосте требуется Python 3.8+.
