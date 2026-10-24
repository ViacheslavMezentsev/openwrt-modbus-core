#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
CC=${CC:-cc}
command -v "$CC" >/dev/null
command -v timeout >/dev/null
build=$(mktemp -d /tmp/modbus-native-io.XXXXXX)
trap 'rm -rf "$build"' EXIT HUP INT TERM
# No test binary is installed or copied to any package/router.
"$CC" -std=c99 -O2 -Wall -Wextra -Werror -pedantic -I"$ROOT/native/io" \
    "$ROOT/native/io/omc_io.c" "$ROOT/scripts/test_native_io.c" -o "$build/host"
timeout 15s "$build/host"
wraps=''
for name in open socket eventfd connect getsockopt read write recv send ioctl poll clock_gettime close; do
    wraps="$wraps -Wl,--wrap=$name"
done
# Intentional word splitting of the generated linker-option list.
# shellcheck disable=SC2086
"$CC" -std=c99 -O2 -Wall -Wextra -Werror -pedantic -I"$ROOT/native/io" \
    "$ROOT/native/io/omc_io.c" "$ROOT/scripts/test_native_io_faults.c" $wraps -o "$build/faults"
timeout 15s "$build/faults"
