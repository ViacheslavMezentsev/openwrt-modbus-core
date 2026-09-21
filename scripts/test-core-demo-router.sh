#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
ROUTER_HOST="${ROUTER_HOST:-openwrt}"
ROUTER_USER="${ROUTER_USER:-root}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa_openwrt}"
SSH_COMMON_ARGS="${SSH_COMMON_ARGS:--o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}"
SSH_OPTS="$SSH_COMMON_ARGS"
MARKER="core-demo-integration-$(date +%s)"

if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="-i $SSH_KEY $SSH_OPTS"
fi

cleanup() {
    "$PROJECT_ROOT/scripts/router-clean-opkg-cache.sh" || true
}
trap cleanup EXIT INT TERM

"$PROJECT_ROOT/scripts/install-ipk-on-router.sh"

ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" /usr/bin/lua - "$MARKER" <<'LUA'
package.path = table.concat({
    "/usr/lib/modbus/?.lua",
    package.path
}, ";")

local events = require("events")
events.set_runtime_dir("/tmp/modbus")
local ok, err = events.record({
    kind = "core_demo_integration",
    marker = arg[1],
    ts = os.time()
})
assert(ok, err)
LUA

attempt=1
while [ "$attempt" -le 10 ]; do
    response="$(ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" 'wget -qO- http://127.0.0.1/cgi-bin/modbus-demo-status')"
    if printf '%s' "$response" | grep -F "\"marker\":\"$MARKER\"" >/dev/null; then
        echo "[router-test] demo received $MARKER"
        exit 0
    fi
    sleep 1
    attempt=$((attempt + 1))
done

echo "FAIL: demo did not receive $MARKER within 10 seconds" >&2
exit 1
