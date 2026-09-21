#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

find_lua() {
    for candidate in lua5.1 lua; do
        if command -v "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

if LUA_BIN="$(find_lua)"; then
    echo "[test] using $LUA_BIN"
    cd "$PROJECT_ROOT"
    exec "$LUA_BIN" scripts/test_core.lua
fi

echo "[test] skipped: install lua5.1 locally to run Lua tests"
