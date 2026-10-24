#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)"
CC=${CC:-cc}
LUA_CFLAGS=${LUA_CFLAGS:--I/usr/include/lua5.1}
build=$(mktemp -d /tmp/schoolbell-media-host.XXXXXX)
trap 'rm -rf "$build"' EXIT HUP INT TERM
mkdir "$build/schoolbell"
# Caller supplied flags intentionally split.
"$CC" -std=c99 -O2 -Wall -Wextra -Werror -pedantic -shared -fPIC $LUA_CFLAGS "$ROOT/packages/schoolbell/tests/media_fs_host.c" -o "$build/schoolbell/media_fs_host.so"
export LUA_CPATH="$build/?.so;;"
export LUA_PATH="$ROOT/packages/schoolbell/lua/?.lua;$ROOT/pkg/usr/lib/?.lua;;"
export MEDIA_HOST=1
python3 "$ROOT/packages/schoolbell/tests/test_media_manager.py" "$ROOT" "$build"
