#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PKG_DIR="${1:-pkg}"
SERVICE_NAME="${2:-modbus-rtu-core}"

ROUTER_HOST="${ROUTER_HOST:-openwrt}"
ROUTER_USER="${ROUTER_USER:-root}"
ROUTER_PATH="${ROUTER_PATH:-/tmp/modbus-deploy}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa_openwrt}"
SSH_COMMON_ARGS="${SSH_COMMON_ARGS:--o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}"
SSH_OPTS="$SSH_COMMON_ARGS"

if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="-i $SSH_KEY $SSH_OPTS"
fi

if [ ! -d "$PROJECT_ROOT/$PKG_DIR" ]; then
    echo "ERROR: package directory not found: $PKG_DIR" >&2
    exit 1
fi

tar -C "$PROJECT_ROOT/$PKG_DIR" -cf - etc usr www 2>/dev/null | \
ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" "mkdir -p '$ROUTER_PATH' && tar -xf - -C '$ROUTER_PATH'"

ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" sh -s -- "$ROUTER_PATH" "$SERVICE_NAME" <<'REMOTE'
set -eu

SRC="$1"
SERVICE_NAME="$2"

[ -d "$SRC/etc" ] && cp -a "$SRC/etc/." /etc/
[ -d "$SRC/usr" ] && cp -a "$SRC/usr/." /usr/
[ -d "$SRC/www" ] && cp -a "$SRC/www/." /www/

[ -f /usr/bin/modbusd ] && chmod 0755 /usr/bin/modbusd
[ -f /www/cgi-bin/modbus-core-status ] && chmod 0755 /www/cgi-bin/modbus-core-status
[ -f "/etc/init.d/$SERVICE_NAME" ] && chmod 0755 "/etc/init.d/$SERVICE_NAME"

mkdir -p /tmp/modbus
mkdir -p /etc/modbus-rtu-core/triggers.d

if [ -x "/etc/init.d/$SERVICE_NAME" ]; then
    "/etc/init.d/$SERVICE_NAME" restart || "/etc/init.d/$SERVICE_NAME" start
fi

rm -rf "$SRC"
REMOTE

echo "Deployed $PKG_DIR to $ROUTER_HOST and restarted $SERVICE_NAME"
