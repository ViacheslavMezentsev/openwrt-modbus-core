#!/bin/sh
set -eu

ROUTER_HOST="${ROUTER_HOST:-openwrt}"
ROUTER_USER="${ROUTER_USER:-root}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa_openwrt}"
SSH_COMMON_ARGS="${SSH_COMMON_ARGS:--o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}"
SSH_OPTS="$SSH_COMMON_ARGS"

if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="-i $SSH_KEY $SSH_OPTS"
fi

ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" '
  rm -rf /tmp/opkg-lists/* 2>/dev/null || true
  rm -f /tmp/*.ipk /tmp/*opkg* 2>/dev/null || true
  echo "[router-clean] opkg cache cleared"
  df -h /overlay
'
