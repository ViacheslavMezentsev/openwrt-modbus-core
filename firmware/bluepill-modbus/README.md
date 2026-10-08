# WeAct BluePill Plus v1.1 USB Modbus RTU

Target: STM32F103C8T6, 64 KiB Flash / 20 KiB RAM. USB CDC carries binary
Modbus RTU, unit 1, 115200 8N1. Do not print text to Serial.
USB is not an electrical RS-485 interface.

## System pins and register map v2

PA0 is reserved for the active-high USER KEY, with internal pull-down.
PB2 is reserved for the active-high system LED. The firmware does NOT
toggle the LED on button presses: only a Modbus coil write controls it.
The button has 30 ms debounce and a 32-bit press counter. A button held at
startup is the baseline, not a new press. The counter resets on MCU reset.

All offsets are zero-based. Read a complete system input-register block
in one FC04 request (address 256, count 8) for a coherent snapshot.

| Table | Offset | Meaning |
| --- | ---: | --- |
| Coil (FC01/05/0F) | 256 | PB2 LED, true = on; off on boot |
| Discrete input (FC02) | 256 | Debounced PA0 button, true = pressed |
| Input register (FC04) | 256 | Signature `0x5741` |
| Input register | 257 | Map version `2` |
| Input register | 258 | Capabilities `3`: bit 0 press counter, bit 1 LED |
| Input register | 259 | Debounced button, 0 or 1 |
| Input registers | 260..261 | Press count, high word then low word |
| Input registers | 262..263 | MCU uptime milliseconds, high word then low word |

Uptime and press count wrap modulo 2^32. On first connection/reconnect,
consumers must establish a baseline, not replay old presses. A future
router handler will compare counters and queue absolute LED commands;
repeated commands then cannot double-toggle. LED coil readback confirms
the firmware setpoint, not electrical/optical LED feedback.

| Table | Offset | General I/O |
| --- | ---: | --- |
| Coils | 0, 1 | DO0 PC13 (legacy active-low), DO1 PB0 (active-high) |
| Discrete inputs | 0, 1 | PB12, PB13, active-low with pull-ups |
| Input registers | 0, 1 | AI0 PA2, AI1 PA1, 12-bit raw ADC |
| Input registers | 2, 3 | AI0, AI1 millivolts using nominal 3.3 V reference |
| Input register | 4 | Legacy 16-bit uptime seconds |
| Holding register | 0 | PA8 PWM, hardware duty clamped to 0..4095 |

PC13 is NOT the onboard WeAct LED. PA0 was AI0 in map v1; map v2 moves
AI0 to PA2. Existing read-only polling still works but must not label AI0
as PA0. PWM is not a DAC; analog output requires external circuitry.
General outputs retain their previous settings until reset or another
write; this prototype has no link-loss safety watchdog.

## Build in WSL

Install Arduino CLI under `~/.local/bin`, then install pinned dependencies:

```sh
CLI="$HOME/.local/bin/arduino-cli"
URL=https://github.com/stm32duino/BoardManagerFiles/raw/main/package_stmicroelectronics_index.json
"$CLI" core update-index --additional-urls "$URL"
"$CLI" core install STMicroelectronics:stm32@3.0.0 --additional-urls "$URL"
"$CLI" lib install modbus-esp8266@4.1.0
sh scripts/build-bluepill.sh
```

The build uses BluePill F103C8, USB CDC generic Serial, Maple DFU 2.0,
size optimization with LTO, and two compiler jobs. It reuses the ignored
`out/bluepill-build` directory. The script checks vector VMA/LMA at
`0x08002000`, a binary size <=57344 bytes, and prints SHA-256.
Arduino's displayed 64 KiB maximum does not deduct the bootloader;
the script enforces the smaller limit. Override CLI with `ARDUINO_CLI`.

Debounce regression test (no board required):

```sh
mkdir -p out
g++ -std=c++11 -Wall -Wextra -Werror scripts/test_button.cpp -o out/test_button
out/test_button
```

## Router upload and recovery

Install the manufacturer's `STM32duino-bootloader-PB2.bin` once via SWD
at `0x08000000`. Do not overwrite it with an application built for SWD.
BOOT0 stays low. Hold KEY, press/release NRST, release KEY when PB2 blinks.
`dfu-util -l` must show `1eaf:0003`, alt 2, Flash `0x8002000`.

Copy the verified application to `/tmp/bluepill.bin` using scp from WSL.
With the core stopped and no other serial clients, run on the router:

```sh
/etc/init.d/modbus-rtu-core stop
dfu-util -d 1eaf:0003 -a 2 -D /tmp/bluepill.bin -R
```

Do not use alt 0, alt 1 or STM32 DfuSe `-s`. After a successful transfer,
press NRST without KEY if needed. Confirm CDC returns and read signature
and map version before any output tests. Then restart the core and remove
the temporary image. USB DFU success alone is not a firmware behavior test.
If upload fails, retain the local image and error log, re-enter the
bootloader, and retry only after diagnosis. ST-Link remains the recovery path.

References: [WeAct board and schematic](https://github.com/WeActStudio/BluePill-Plus),
[WeAct bootloaders](https://github.com/WeActStudio/BluePill-Plus/tree/master/SDK/STM32F103C8T6/Arduino).
