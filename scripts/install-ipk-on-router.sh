#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/out}"
ROUTER_HOST="${ROUTER_HOST:-openwrt}"
ROUTER_USER="${ROUTER_USER:-root}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa_openwrt}"
SSH_COMMON_ARGS="${SSH_COMMON_ARGS:--o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}"
SSH_OPTS="$SSH_COMMON_ARGS"

if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="-i $SSH_KEY $SSH_OPTS"
fi

if [ -n "${BUILD_VERSION:-}" ]; then
    CORE_IPK="$OUT_DIR/modbus-rtu-core_${BUILD_VERSION}_all.ipk"
    DEMO_IPK="$OUT_DIR/modbus-demo_${BUILD_VERSION}_all.ipk"
else
    CORE_IPK="$(ls "$OUT_DIR"/modbus-rtu-core_*.ipk | sort -V | tail -n 1)"
    DEMO_IPK="$(ls "$OUT_DIR"/modbus-demo_*.ipk | sort -V | tail -n 1)"
fi

[ -f "$CORE_IPK" ] || {
    echo "ERROR: core .ipk not found in $OUT_DIR" >&2
    exit 1
}

[ -f "$DEMO_IPK" ] || {
    echo "ERROR: demo .ipk not found in $OUT_DIR" >&2
    exit 1
}

scp $SSH_OPTS "$CORE_IPK" "$DEMO_IPK" "$ROUTER_USER@$ROUTER_HOST:/tmp/"

ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" sh -s -- "$(basename "$CORE_IPK")" "$(basename "$DEMO_IPK")" <<'REMOTE'
set -eu

CORE_IPK="/tmp/$1"
DEMO_IPK="/tmp/$2"

opkg install --force-overwrite --force-reinstall "$CORE_IPK"
opkg install --force-overwrite --force-reinstall "$DEMO_IPK"
/etc/init.d/modbus-rtu-core restart >/dev/null 2>&1 || true
/etc/init.d/modbus-demo restart >/dev/null 2>&1 || true
REMOTE

echo "Installed .ipk packages on router via opkg"
