# Нативные I/O-примитивы

[English](NATIVE_IO.en.md) · [Lua API](IO_ADAPTER_API.md) · [C API](../../native/io/omc_io.h)

Ревизия ТЗ 1.33, 24.10.2026. Первый изолированный C-слой для Linux.
Не является готовым backend: Lua binding, соединение с io_adapter/states/scheduler,
целевой MIPS ABI и отдельный IPK ещё не реализованы/не проверены.
Ничего не загружается в modbusd и не добавляется в скриптовый IPK ядра.

## Сборка и проверки

```sh
make build-native-io
make test-native-io
```

Сборка создаёт `out/native-io/libomc-io.a`. Нужны Linux headers, C99 compiler,
ar; штатным host-тестам также нужен timeout (coreutils). Тесты включены в
`make all`/`make ci-core` и не пропускаются при отсутствии компилятора.
Сборка библиотеки отдельно принимает CC/AR/CFLAGS/CPPFLAGS/BUILD; кросс-сборка
сами host-тесты не запускает. Заголовки asm берутся из sysroot выбранного ABI.
Скриптовый `make build` по-прежнему не требует OpenWrt SDK.

## Граница примитива

| Группа | Действие |
| --- | --- |
| clock | CLOCK_MONOTONIC, целые миллисекунды uint64_t |
| open | serial: open с NONBLOCK/CLOEXEC/NOCTTY/NOFOLLOW; TCP: socket с NONBLOCK/CLOEXEC; wake: eventfd с NONBLOCK/CLOEXEC |
| prepare | Чистая подготовка числового IPv4/порта и kernel termios 8N1 |
| configure | Один ioctl TCSETS; без tcgetattr/tcsetattr/tcdrain и flush |
| connect/status | Один connect либо getsockopt SO_ERROR после готовности |
| RX/TX | Один read/write для serial, recv/send для TCP; не более 512/260 байт |
| probes | TIOCOUTQ и TIOCSERGETLSR — два отдельных вызова |
| wait/wake | Один poll до 8 fd и 0–100 мс; одна запись/одно чтение eventfd |
| close | Сброс handle до одного close, без повтора на том же fd |

Каждая функция `*_once` вызывает не более одного системного примитива libc;
входная ошибка — ноль. Нет внутренних повторов EINTR/EAGAIN, циклов передачи,
DNS, неявного fcntl или heap allocation. Clock может обслуживаться vDSO.
Это ограничение числа вызовов, а не доказанный максимальный срок их исполнения.
Чистые prepare-функции не входят в syscall-бюджет.

Результат ошибки — -1 и errno; successful read/write возвращает фактическое
число байт. Ноль TCP read означает EOF; ноль serial read при VMIN=0 сам по себе
не означает disconnect. EAGAIN/EINTR и short/zero write не скрываются.
SO_ERROR читается только после подходящего события connect; его ноль вне этого
контекста не доказывает соединение. TCP send использует MSG_DONTWAIT и
MSG_NOSIGNAL: ошибка peer не завершает процесс SIGPIPE. См. [send(2)](https://man7.org/linux/man-pages/man2/send.2.html).

Числовые errno, struct termios и структуры API являются внутренними, зависят
от ABI и не сериализуются. Kernel termios из asm/termbits.h нельзя смешивать
с libc termios.h в одном translation unit. Подготовка 8N1 задаёт CLOCAL/CREAD,
отключает software/hardware flow control, HUPCL, преобразования и echo;
VMIN/VTIME=0, одинаковая скорость приёма/передачи. Поддержанный начальный набор:
1200/2400/4800/9600/19200/38400/57600/115200; B0 и неизвестные скорости отвергаются.
Это не расширяет требования к скорости конкретного устройства.

## Владение и дальнейшая композиция

Handle и буферы принадлежат доверенному однопоточному вызывающему. Handle
инициализируется OMC_HANDLE_INIT, не копируется в живом состоянии; чужой close,
изменение флагов и положительный SO_LINGER запрещены контрактом владельца.
Повторное open в живой handle отклоняется. fd=0 допустим. Close инвалидирует
handle и при EINTR/ошибке: на Linux повтор мог бы закрыть уже чужой ресурс,
см. [close(2)](https://man7.org/linux/man-pages/man2/close.2.html).

Serial path должен быть заранее доверенно разрешён к нужному char device;
NOFOLLOW защищает только последний компонент. Здесь нет USB resolver, проверки
идентичности/владельца пути и защиты от его гонок; это блокирует production-интеграцию.
Настройка и её возможная проверка — отдельные шаги будущего автомата, каждый
учитывается в квоте. Не добавлены скрытые flush, exclusive-lock или recovery.

Poll принимает заимствованный снимок fd; он не хранит token и не фильтрует старые
поколения. При ошибке revents использовать нельзя. Владелец сохраняет соответствие
снимка endpoint/connection/operation/attempt и применяет проверку поколения.
Восемь элементов — семь endpoint плюс wake; публичный IPC пока не входит в этот API.
Wake накапливает счётчик; drain считывает его одним вызовом. EAGAIN при насыщении
означает уже ожидающее уведомление, а не разрешение на повтор в цикле;
см. [eventfd(2)](https://man7.org/linux/man-pages/man2/eventfd.2.html).
Будущая Lua-обвязка ограничит точные миллисекунды диапазоном 2^53-1 и нормализует
errno. Она же связывает permit/deadline, четыре вызова, токены и wake-бюджет.
C-примитивы сами не разрешают Modbus-запись, не выполняют retries и не знают STOP.

## Доказательства и ограничения

TC-142: linker wrappers проверяют EINTR/EAGAIN/EIO на всех 17 путях операций,
ровно один вызов, отсутствие изменения выходных значений при отказе,
short/zero I/O, SO_ERROR, fd=0, повторное open/close и входные пределы.
TC-143: реальные loopback TCP connect/data/EOF/refused, SIGPIPE с default handler,
raw PTY с бинарными данными и чтением termios, eventfd coalescing/saturation,
poll EINTR от сигнала, монотонность и 200 циклов FD без утечки.
Тестовые процессы ограничены внешним timeout; это защита теста, не runtime-гарантия.

PTY возвращает ENOTTY для LSR. Пустая очередь драйвера не доказывает выход на
провод; LSR — лишь свидетельство драйвера, не автоматически разрешённая capability.
Слой не объявляет bounded_setup/bounded_close/rtu_tx_complete=true.
Нужны анализ целевого libc/драйвера, сборка/поставка для MIPS, ограниченность
open/configure/close, обоснование TX completion и общий RAM/latency budget.
TC-134–138 остаются частичными, TC-139 командного слоя плановый.
Аппаратных операций, runtime-интеграции и новых разрешений для ровера нет.
