#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
ROUTER_HOST="${ROUTER_HOST:-openwrt}"
ROUTER_USER="${ROUTER_USER:-root}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa_openwrt}"
SSH_COMMON_ARGS="${SSH_COMMON_ARGS:--o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}"
SSH_OPTS="$SSH_COMMON_ARGS"

if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="-i $SSH_KEY $SSH_OPTS"
fi

"$PROJECT_ROOT/scripts/install-ipk-on-router.sh"

ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" '
  set -eu
  sleep 3
  echo "=== installed packages ==="
  opkg list-installed | grep -E "^modbus-" || true
  echo "=== services ==="
  ps | grep modbus | grep -v grep || true
  echo "=== core status ==="
  cat /tmp/modbus/cache.json
  echo
  echo "=== demo status ==="
  cat /tmp/modbus/demo-status.json
  echo
  echo "=== cgi checks ==="
  wget -qO- http://127.0.0.1/cgi-bin/modbus-core-status
  echo
  wget -qO- http://127.0.0.1/cgi-bin/modbus-demo-status
  echo
  echo "=== opkg cleanup ==="
  rm -rf /tmp/opkg-lists/* 2>/dev/null || true
  rm -f /tmp/*.ipk /tmp/*opkg* 2>/dev/null || true
  df -h /overlay
'

echo "=== remove packages ==="
ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" '
  set -eu
  opkg remove modbus-demo
  opkg remove modbus-rtu-core
  echo "=== installed after remove ==="
  opkg list-installed | grep -E "^modbus-" || true
'

echo "=== reinstall packages ==="
"$PROJECT_ROOT/scripts/install-ipk-on-router.sh"

ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" '
  set -eu
  sleep 3
  echo "=== installed after reinstall ==="
  opkg list-installed | grep -E "^modbus-" || true
  echo "=== services after reinstall ==="
  ps | grep modbus | grep -v grep || true
  echo "=== final opkg cleanup ==="
  rm -rf /tmp/opkg-lists/* 2>/dev/null || true
  rm -f /tmp/*.ipk /tmp/*opkg* 2>/dev/null || true
  df -h /overlay
'
