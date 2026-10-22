# I/O-адаптер: проверка хоста и тестовый API

[English](IO_ADAPTER_API.en.md) · [Контракт](SYSTEM_IO_CONTRACT.md)

Р.1.32, 22.10.2026. [io_adapter.lua](../../pkg/usr/lib/modbus/io_adapter.lua)
входит в IPK как изолированный модуль без системных вызовов по умолчанию.
[20 групп тестов](../../scripts/test_io_adapter.lua) работают с подменами.
Модуль НЕ соединён с transport_state/scheduler/modbusd. Это не готовый RTU/TCP backend.

## Проверенные основания

Исследованы исходники nixio ветки openwrt-19.07, закреплённый commit
f25285a6c26e8776f153994704710cb8e51fad91:
[file.c](https://github.com/openwrt/luci/blob/f25285a6c26e8776f153994704710cb8e51fad91/libs/luci-lib-nixio/src/file.c),
[io.c](https://github.com/openwrt/luci/blob/f25285a6c26e8776f153994704710cb8e51fad91/libs/luci-lib-nixio/src/io.c),
[poll.c](https://github.com/openwrt/luci/blob/f25285a6c26e8776f153994704710cb8e51fad91/libs/luci-lib-nixio/src/poll.c).
В read/write есть скрытые циклы EINTR. Они не дают вызывающему Lua проверить срок
между каждым syscall и посчитать четыре вызова. Для нового пути нужен отдельный
минимальный нативный слой одиночных вызовов; существующие потребители nixio не меняются.
Этот исходный commit не доказывает точную версию библиотеки на роутере.

На Linux WSL2 x86_64 проверены CLOCK_MONOTONIC, eventfd/poll, неблокирующий
loopback TCP connect + SO_ERROR + данные/EOF, raw/nonblocking PTY.
TIOCOUTQ на PTY дал 0; TIOCSERGETLSR — ENOTTY. Это доступность механизма на хосте,
не доказательство границы времени syscall, USB TX timing или поддержки OpenWrt.
Пробы выполнялись отдельно с общим timeout, не включены в CI как аппаратный PASS.

## API доверенного драйвера

new(sys, capabilities) требует явных функций, без fallback на nixio/io.open.
capabilities.single_call/bounded_setup/bounded_close должны быть true;
rtu_tx_complete — boolean. Это утверждения доверенного поставщика backend,
не автоматическая сертификация. RTU без TX capability отклоняется до открытия.

| Метод | Смысл |
| --- | --- |
| prepare(id, config, token, deadline) | Скопировать контекст, начать подготовку; ещё без syscall |
| service(id, permit, ready) | До 4 примитивов, до 512 байт и одного возвращаемого события |
| transmit(id, token, bytes, deadline) | Ограниченный wire-буфер 1–260 байт, срок только сокращается |
| finish(id, token) | Парсер признал ответ завершённым; соединение остаётся idle |
| begin(id, new_token, deadline) | Следующая операция/попытка на idle-соединении |
| cancel(id, token) | Отмена; error и cleanup выдаются последующими service |
| close(id) | Cleanup при shutdown; результат операции уже должен обслужить владелец транспорта |
| wait(timeout_ms) | Один poll, без скрытого повтора EINTR; при wake — один drain |
| notify() | Один неблокирующий wake; повторные уведомления объединяются |
| capabilities() | Копия декларации backend |

token = {connection, operation, attempt}: положительные целые до 2^53-1.
Новая операция/попытка строго возрастает, после close нужен больший connection.
Переполнение требует остановки/нового жизненного цикла, а не оборачивания.
Идентификаторы клиента и internal token различаются.

config содержит kind, address, port для TCP или baud для RTU. Это форма тестового
API, не полноценный валидатор UCI/USB identity. Production должен использовать
проверенную конфигурацию; числовой адрес TCP передаётся без DNS.
permit(token) — доверенная ограниченная синхронная проверка актуального разрешения;
проверяется перед I/O, часы перечитываются после callback и syscall.

sys содержит clock, open, configure, connect, connect_status, write, read,
tx_empty, close, poll, wake, drain_wake. Каждый примитив транспорта соответствует
ОДНОМУ syscall без внутреннего EINTR retry. Например configure — только применение
заранее подготовленных termios, не пакет tcgetattr/tcsetattr; дополнительные
необходимые native-шаги потребуется явно добавить в автомат и бюджет.
Результат примитива: значение либо nil, нормализованный errno.
tx_empty=false означает неподтверждённый TX; TCP completion не означает Modbus ack.
Неожиданное исключение write консервативно отмечается как возможная отправка.
Backend должен сохранять учёт выделенного ресурса даже при собственных ошибках.

ready содержит token, readable/writable/error и для RX capacity (0–520).
Устаревший token игнорируется. RX ограничивается min(512, capacity).
События prepared/tx_progress/tx_complete/rx/error/closed содержат endpoint и
копию token. service возвращает calls/bytes/clock_reads и event, а не накопительную
очередь. Вызывающий обязан обработать событие до следующего service.
error завершает работу попытки; closed сообщает последующую очистку, не второй
терминальный результат Modbus. Поле may_have_sent — факт для транспортного слоя,
который формирует not_sent/unknown; модуль не знает функцию Modbus.

## Квоты и ожидание

4 вызова на endpoint за service, включая ошибки, максимум 28 для прохода семи
endpoint. Внешний диспетчер вызывает service каждого endpoint только один раз за
проход; сам модуль не заменяет round scheduler и его 8 переходов.
Часы учитываются отдельно. У poll/wake отдельный бюджет: один poll и до двух
операций пробуждения за проход; notify должен ограничиваться диспетчером.
Реальный публичный IPC здесь не реализован.

EINTR/EAGAIN возвращают управление без повтора syscall внутри service.
Для подготовки/TX-probe повтор не раньше следующей миллисекунды; это защита
от нулевого busy loop, не разрешение продлить deadline. Нулевой write непустого
буфера — ошибка. wait принимает 0–100 мс и сокращает ожидание по deadline/повтору;
вызывающий дополнительно ограничивает его scheduler quantum.
Idle не подписывается на POLLOUT; активный send/connect подписывается.
Внешний управляющий IPC должен входить в общий poll при будущей интеграции;
notify не создаёт фонового Lua-потока и не заменяет приём STOP.

Cleanup продолжает service после error/отмены. Close не повторяется на том же
числовом fd после ошибки: он мог быть освобождён/переиспользован Linux.
Нельзя просто забыть адаптер с открытыми ресурсами. Резервы сборки остаются
ответственностью scheduler; их совместный cleanup ещё требует интеграции.

## Следующий этап

Минимальная нативная зависимость: сборка для нужных ABI, одиночные вызовы,
CLOCK_MONOTONIC, poll/wakeup, termios/TX capability и проверенное закрытие.
Её размер/поставка и ограниченность реальных операций ещё не проверены.
Скриптовое ядро продолжает собираться без SDK; сборка зависимости — отдельная.
Затем связать адаптер с Lua-состояниями/планировщиком на fake I/O и измерить RAM.
TC-134–138 покрыты частично; TC-139 командного слоя остаётся плановым.
Ни управляющие записи ровера, ни сеть, ни установленное ядро не изменены.
