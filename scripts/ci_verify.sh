#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/out}"
CONTROL_FILE="$PROJECT_ROOT/pkg/CONTROL/control"

find_tool() {
    for candidate in "$@"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

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
    "$PROJECT_ROOT/pkg/usr/bin/modbus" \
    "$PROJECT_ROOT/pkg/www/cgi-bin/modbus-core-status" \
    "$PROJECT_ROOT/pkg-demo/CONTROL/postinst" \
    "$PROJECT_ROOT/pkg-demo/CONTROL/prerm" \
    "$PROJECT_ROOT/pkg-demo/etc/init.d/modbus-demo" \
    "$PROJECT_ROOT/pkg-demo/usr/bin/modbus-demo" \
    "$PROJECT_ROOT/pkg-demo/www/cgi-bin/modbus-demo-status" \
    "$PROJECT_ROOT/scripts/build-ipk.sh" \
    "$PROJECT_ROOT/scripts/deploy.sh" \
    "$PROJECT_ROOT/scripts/ci_verify.sh" \
    "$PROJECT_ROOT/scripts/install-ipk-on-router.sh" \
    "$PROJECT_ROOT/scripts/router-clean-opkg-cache.sh" \
    "$PROJECT_ROOT/scripts/run-tests.sh" \
    "$PROJECT_ROOT/scripts/test-core-demo-router.sh" \
    "$PROJECT_ROOT/scripts/test-opkg-lifecycle.sh"
do
    [ -x "$file" ] || {
        echo "FAIL: file must be executable: $file" >&2
        exit 1
    }
done

echo "[verify] checking shell syntax"
for file in "$PROJECT_ROOT"/scripts/*.sh \
    "$PROJECT_ROOT/pkg/CONTROL/postinst" \
    "$PROJECT_ROOT/pkg/CONTROL/prerm" \
    "$PROJECT_ROOT/pkg/etc/init.d/modbus-rtu-core" \
    "$PROJECT_ROOT/pkg/www/cgi-bin/modbus-core-status" \
    "$PROJECT_ROOT/pkg-demo/CONTROL/postinst" \
    "$PROJECT_ROOT/pkg-demo/CONTROL/prerm" \
    "$PROJECT_ROOT/pkg-demo/etc/init.d/modbus-demo" \
    "$PROJECT_ROOT/pkg-demo/www/cgi-bin/modbus-demo-status"
do
    sh -n "$file"
done

if LUAC_BIN="$(find_tool luac5.1 luac)"; then
    echo "[verify] checking Lua syntax with $LUAC_BIN"
    for file in "$PROJECT_ROOT"/pkg/usr/lib/modbus/*.lua \
        "$PROJECT_ROOT/pkg/usr/bin/modbusd" \
        "$PROJECT_ROOT/pkg/usr/bin/modbus" \
        "$PROJECT_ROOT/pkg-demo/usr/bin/modbus-demo" \
        "$PROJECT_ROOT"/scripts/test_*.lua
    do
        "$LUAC_BIN" -p "$file"
    done
else
    echo "[verify] skipped Lua syntax check: install lua5.1 locally"
fi

echo "[verify] checking package metadata"
grep -qx 'Package: modbus-rtu-core' "$PROJECT_ROOT/pkg/CONTROL/control"
grep -qx 'Architecture: all' "$PROJECT_ROOT/pkg/CONTROL/control"
grep -q '^Depends: .*luci-lib-jsonc' "$PROJECT_ROOT/pkg/CONTROL/control"
grep -qx 'Package: modbus-demo' "$PROJECT_ROOT/pkg-demo/CONTROL/control"
grep -q '^Depends: .*modbus-rtu-core' "$PROJECT_ROOT/pkg-demo/CONTROL/control"

echo "[verify] checking package artifacts"
found_ipk=0
for ipk in "$OUT_DIR"/*.ipk; do
    [ -f "$ipk" ] || continue
    found_ipk=1
    tar -tzf "$ipk" | grep -qx "\./debian-binary"
    tar -tzf "$ipk" | grep -qx "\./control.tar.gz"
    tar -tzf "$ipk" | grep -qx "\./data.tar.gz"

    artifact_dir="$(mktemp -d)"
    mkdir "$artifact_dir/control" "$artifact_dir/data"
    tar -xzf "$ipk" -C "$artifact_dir"
    tar -xzf "$artifact_dir/control.tar.gz" -C "$artifact_dir/control"
    tar -xzf "$artifact_dir/data.tar.gz" -C "$artifact_dir/data"
    [ "$(cat "$artifact_dir/debian-binary")" = "2.0" ]
    case "$(basename "$ipk")" in
        modbus-rtu-core_*)
            [ -f "$artifact_dir/control/control" ]
            [ -f "$artifact_dir/data/usr/bin/modbusd" ]
            [ -f "$artifact_dir/data/etc/init.d/modbus-rtu-core" ]
            [ -f "$artifact_dir/data/www/cgi-bin/modbus-core-status" ]
            ;;
        modbus-demo_*)
            [ -f "$artifact_dir/control/control" ]
            [ -f "$artifact_dir/data/usr/bin/modbus-demo" ]
            [ -f "$artifact_dir/data/etc/init.d/modbus-demo" ]
            [ -f "$artifact_dir/data/www/cgi-bin/modbus-demo-status" ]
            ;;
    esac
    rm -rf "$artifact_dir"
done

[ "$found_ipk" -eq 1 ] || {
    echo "FAIL: no .ipk artifacts found in $OUT_DIR" >&2
    exit 1
}

echo "[verify] OK"
