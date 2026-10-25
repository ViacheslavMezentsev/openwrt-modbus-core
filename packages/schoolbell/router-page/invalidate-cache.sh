#!/bin/sh
# Run on the router after updating the engineering payload, before UI verification.
# LuCI bytecode may outlive reproducibly dated payload sources.
set -eu
for file in /tmp/luci-modulecache/7363686F6F6C62656C6C2E* /tmp/luci-modulecache/6C7563692E636F6E74726F6C6C65722E7363686F6F6C62656C6C5F74657374; do
    [ ! -f "$file" ] || rm -f "$file"
done
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.*.json
