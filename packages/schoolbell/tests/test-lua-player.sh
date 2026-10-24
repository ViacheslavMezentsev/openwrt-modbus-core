#!/bin/sh
set -eu
ulimit -c 0
ROOT="$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)"
CC=${CC:-cc}
LUA_CFLAGS=${LUA_CFLAGS:--I/usr/include/lua5.1}
LUA_LIBS=${LUA_LIBS:--llua5.1}
command -v "$CC" >/dev/null
command -v timeout >/dev/null
build=$(mktemp -d /tmp/schoolbell-lua-player.XXXXXX)
trap 'rm -rf "$build"' EXIT HUP INT TERM
mkdir "$build/schoolbell"
"$CC" -std=c99 -O2 -Wall -Wextra -Werror -pedantic "$ROOT/packages/schoolbell/tests/player_child.c" -o "$build/child"
# LUA_CFLAGS/LUA_LIBS are caller-supplied build flags; intentional word splitting.
"$CC" -std=c99 -O2 -Wall -Wextra -Werror -pedantic -fPIC -shared $LUA_CFLAGS \
    "$ROOT/packages/schoolbell/native/player.c" "$ROOT/packages/schoolbell/native/player_lua.c" \
    -lm -o "$build/schoolbell/player_linux.so"
"$CC" -std=c99 -O2 -Wall -Wextra -Werror -pedantic $LUA_CFLAGS \
    "$ROOT/packages/schoolbell/tests/lua_player_host.c" $LUA_LIBS -lm -ldl -Wl,--export-dynamic -o "$build/host"
LUA_CPATH="$build/?.so" timeout 30s "$build/host" "$build/child" "$build" "$ROOT/packages/schoolbell/tests/test_player_linux.lua"

cd "$ROOT"
LUA_CPATH="$build/?.so" timeout 30s "$build/host" "$build/child" "$build" "$ROOT/packages/schoolbell/tests/test_queue_linux.lua"
