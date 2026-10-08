#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CLI=${ARDUINO_CLI:-$HOME/.local/bin/arduino-cli}
DATA=${ARDUINO_DIRECTORIES_DATA:-$HOME/.arduino15}
CORE="$DATA/packages/STMicroelectronics/hardware/stm32/3.0.0"
OBJDUMP="$DATA/packages/STMicroelectronics/tools/xpack-arm-none-eabi-gcc/14.2.1-1.1/bin/arm-none-eabi-objdump"
FQBN='STMicroelectronics:stm32:GenF1:pnum=BLUEPILL_F103C8,usb=CDCgen,opt=oslto,upload_method=dfu2Method'
BUILD="$ROOT/out/bluepill-build"

test -d "$CORE" || { echo 'Install STMicroelectronics:stm32@3.0.0 first.' >&2; exit 1; }
test -x "$OBJDUMP" || { echo 'Expected ARM toolchain missing.' >&2; exit 1; }
"$CLI" core list | grep -Eq '^STMicroelectronics:stm32[[:space:]]+3\.0\.0([[:space:]]|$)' || {
    echo 'This build requires the active STM32 core to be 3.0.0.' >&2; exit 1;
}
"$CLI" lib list | grep -Eq '^modbus-esp8266[[:space:]]+4\.1\.0([[:space:]]|$)' || {
    echo 'Install modbus-esp8266@4.1.0 first.' >&2; exit 1;
}
mkdir -p "$BUILD"
"$CLI" compile --jobs 2 --fqbn "$FQBN" --build-path "$BUILD" \
    "$ROOT/firmware/bluepill-modbus/bluepill_modbus"

ELF="$BUILD/bluepill_modbus.ino.elf"
BIN="$BUILD/bluepill_modbus.ino.bin"
VECTOR=$("$OBJDUMP" -h "$ELF" | awk '$2 == ".isr_vector" { print $4 ":" $5 }')
test "$VECTOR" = '08002000:08002000' || {
    echo "Unsafe vector address (VMA:LMA): $VECTOR" >&2; exit 1;
}
BYTES=$(wc -c < "$BIN")
test "$BYTES" -gt 0 && test "$BYTES" -le 57344 || {
    echo "Image exceeds the F103C8 Maple budget: $BYTES bytes" >&2; exit 1;
}
printf 'Maple image: %s\nSize: %s / 57344 bytes\nVector address: 0x08002000\n' "$BIN" "$BYTES"
sha256sum "$BIN"
echo 'Build only; this script never flashes the board.'
