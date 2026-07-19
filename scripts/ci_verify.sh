#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/out}"
CONTROL_FILE="$PROJECT_ROOT/pkg/CONTROL/control"

echo "[verify] checking required files"
[ -f "$CONTROL_FILE" ]
[ -f "$PROJECT_ROOT/pkg/etc/init.d/modbus-rtu-core" ]
[ -f "$PROJECT_ROOT/pkg/usr/bin/modbusd" ]
[ -f "$PROJECT_ROOT/pkg-demo/CONTROL/control" ]
[ -f "$PROJECT_ROOT/pkg-demo/etc/init.d/modbus-demo" ]
[ -f "$PROJECT_ROOT/pkg-demo/usr/bin/modbus-demo" ]

echo "[verify] checking executable bits in package sources"
for file in \
    "$PROJECT_ROOT/pkg/CONTROL/postinst" \
    "$PROJECT_ROOT/pkg/CONTROL/prerm" \
    "$PROJECT_ROOT/pkg/etc/init.d/modbus-rtu-core" \
    "$PROJECT_ROOT/pkg/usr/bin/modbusd" \
    "$PROJECT_ROOT/pkg/www/cgi-bin/modbus-core-status" \
    "$PROJECT_ROOT/pkg-demo/CONTROL/postinst" \
    "$PROJECT_ROOT/pkg-demo/CONTROL/prerm" \
    "$PROJECT_ROOT/pkg-demo/etc/init.d/modbus-demo" \
    "$PROJECT_ROOT/pkg-demo/usr/bin/modbus-demo" \
    "$PROJECT_ROOT/pkg-demo/www/cgi-bin/modbus-demo-status" \
    "$PROJECT_ROOT/scripts/build-ipk.sh" \
    "$PROJECT_ROOT/scripts/deploy.sh" \
    "$PROJECT_ROOT/scripts/ci_verify.sh"
do
    [ -x "$file" ] || {
        echo "FAIL: file must be executable: $file" >&2
        exit 1
    }
done

echo "[verify] checking package artifacts"
found_ipk=0
for ipk in "$OUT_DIR"/*.ipk; do
    [ -f "$ipk" ] || continue
    found_ipk=1
    ar t "$ipk" | grep -qx "debian-binary"
    ar t "$ipk" | grep -qx "control.tar.gz"
    ar t "$ipk" | grep -qx "data.tar.gz"
done

[ "$found_ipk" -eq 1 ] || {
    echo "FAIL: no .ipk artifacts found in $OUT_DIR" >&2
    exit 1
}

echo "[verify] OK"
