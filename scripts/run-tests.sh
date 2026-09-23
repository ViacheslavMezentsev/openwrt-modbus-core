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
    "$LUA_BIN" scripts/test_core.lua
    "$LUA_BIN" scripts/test_rtu.lua
    test_dir="$(mktemp -d /tmp/modbus-topics-test.XXXXXX)"
    trap 'rm -rf "$test_dir"' EXIT
    "$LUA_BIN" scripts/test_topics.lua "$test_dir"
    exit 0
fi

echo "[test] skipped: install lua5.1 locally to run Lua tests"
