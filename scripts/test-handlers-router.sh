#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
HOST=${ROUTER_HOST:-openwrt}
remote=$(timeout 15 ssh -T -o BatchMode=yes -o ConnectTimeout=5 "$HOST" 'mktemp -d /tmp/modbus-handler-test.XXXXXX')
case "$remote" in /tmp/modbus-handler-test.*) ;; *) exit 1 ;; esac
trap 'timeout 15 ssh -T "$HOST" "rm -rf $remote"' EXIT
tar -czf - pkg/usr/lib/modbus pkg/etc/modbus-rtu-core/handlers.d pkg/usr/bin/modbusd scripts/test_handlers.lua scripts/test_rtu.lua scripts/test_topics.lua scripts/test_core.lua scripts/test_resilience.lua scripts/test_events.lua |
    timeout 20 ssh -T "$HOST" "tar -xzf - -C $remote"
timeout 25 ssh -T "$HOST" "cd $remote && mkdir -p topics && lua -e 'assert(loadfile(\"pkg/usr/bin/modbusd\"))' && lua scripts/test_core.lua $remote/core && lua scripts/test_topics.lua $remote/topics && lua scripts/test_rtu.lua && lua scripts/test_handlers.lua $remote && lua scripts/test_resilience.lua $remote && lua scripts/test_events.lua $remote"
