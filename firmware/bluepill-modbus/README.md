# BluePill USB CDC Modbus RTU

This sketch makes a WeAct BluePill with STM32F103CB a Modbus RTU server with
unit ID `1`. The router sees the board through its USB CDC endpoint as
`/dev/ttyACM0`.

## Scope

This is a bench prototype. USB CDC carries Modbus RTU bytes but is not an
electrical RS-485 bus. The future gateway firmware will use one or more UART
interfaces with RS-485 transceivers while retaining a separate management
protocol to the router.

The sketch requires Arduino Core STM32 and `modbus-esp8266` version `4.1.0`.
The library provides the RTU server API and works with Arduino platforms.

## Register map

All offsets below are zero-based Modbus addresses.

| Function | Offset | Meaning |
| --- | ---: | --- |
| Read/Write Coils (0x01/0x05/0x0F) | 0 | DO0: built-in PC13 LED, active low |
| Read/Write Coils (0x01/0x05/0x0F) | 1 | DO1: PB0 |
| Read Discrete Inputs (0x02) | 0 | DI0: PB12, active low with pull-up |
| Read Discrete Inputs (0x02) | 1 | DI1: PB13, active low with pull-up |
| Read Input Registers (0x04) | 0 | AI0: PA0 raw ADC value, `0..4095` |
| Read Input Registers (0x04) | 1 | AI1: PA1 raw ADC value, `0..4095` |
| Read Input Registers (0x04) | 2 | AI0 in millivolts, nominal range `0..3300` |
| Read Input Registers (0x04) | 3 | AI1 in millivolts, nominal range `0..3300` |
| Read Input Registers (0x04) | 4 | Firmware uptime in seconds, truncated to 16 bits |
| Read/Write Holding Registers (0x03/0x06/0x10) | 0 | AO0 prototype: PWM duty cycle on PA8, `0..4095` |

STM32F103CB has ADC peripherals but no integrated DAC. Therefore AO0 is PWM
for this prototype; an external DAC or an RC filter is required for a real
analog output.

## First flash on a laptop

1. Install Arduino IDE 2 and add the STM32 Boards Manager URL:
   `https://github.com/stm32duino/BoardManagerFiles/raw/main/package_stmicroelectronics_index.json`.
2. Install `STM32 MCU based boards` and the Arduino library `modbus-esp8266`
   at version `4.1.0`.
3. Install STM32CubeProgrammer. It is required by the STM32duino upload flow.
4. Connect an ST-Link to `GND`, `PA13/SWDIO`, and `PA14/SWCLK`. Connect its
   `3.3V` pin only when the board is not already USB powered.
5. In Arduino IDE select `Generic STM32F1 series`, then `BluePill F103CB`.
   Select `STM32CubeProgrammer (SWD)` as Upload Method and
   `CDC (generic Serial supersedes U(S)ART)` as USB Support. Keep `BOOT0` low.
6. Open `bluepill_modbus.ino`, upload it, disconnect ST-Link, reset the board,
   and reconnect its USB port.

Do not use a serial monitor after flashing: the CDC endpoint carries binary
Modbus frames. On Linux, reconnection should expose `/dev/ttyACM*`.

## Router handoff

After connecting the flashed board to the router, verify it appears as
`/dev/ttyACM0` and record its USB VID/PID. The next core stage will add the
router-side Modbus master transport, stable device naming, and tests for this
register map.
