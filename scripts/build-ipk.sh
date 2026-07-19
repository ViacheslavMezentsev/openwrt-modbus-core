#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PKG_DIR="${PKG_DIR:-pkg}"
OUT_DIR_INPUT="${OUT_DIR:-$PROJECT_ROOT/out}"
VERSION="${BUILD_VERSION:-0.1.0}"
ARCHITECTURE="${ARCHITECTURE:-all}"
OUT_DIR="$OUT_DIR_INPUT"

case "$OUT_DIR" in
    /*) ;;
    *) OUT_DIR="$PROJECT_ROOT/$OUT_DIR" ;;
esac

CONTROL_FILE="$PROJECT_ROOT/$PKG_DIR/CONTROL/control"
if [ ! -f "$CONTROL_FILE" ]; then
    echo "ERROR: control file not found: $CONTROL_FILE" >&2
    exit 1
fi

PACKAGE_NAME="$(sed -n 's/^Package:[[:space:]]*//p' "$CONTROL_FILE" | head -n 1)"
if [ -z "$PACKAGE_NAME" ]; then
    echo "ERROR: unable to read Package from $CONTROL_FILE" >&2
    exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ipk-build.XXXXXX")"
CONTROL_DIR="$STAGING_DIR/control"
DATA_DIR="$STAGING_DIR/data"
FINAL_DIR="$STAGING_DIR/final"
IPK_FILE="$OUT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCHITECTURE}.ipk"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$CONTROL_DIR" "$DATA_DIR" "$FINAL_DIR" "$OUT_DIR"
cp -a "$PROJECT_ROOT/$PKG_DIR/CONTROL/." "$CONTROL_DIR/"

for entry in etc usr www; do
    if [ -d "$PROJECT_ROOT/$PKG_DIR/$entry" ]; then
        mkdir -p "$DATA_DIR/$entry"
        cp -a "$PROJECT_ROOT/$PKG_DIR/$entry/." "$DATA_DIR/$entry/"
    fi
done

sed -i "s/^Version:.*/Version: $VERSION/" "$CONTROL_DIR/control"
sed -i "s/^Architecture:.*/Architecture: $ARCHITECTURE/" "$CONTROL_DIR/control"

(cd "$CONTROL_DIR" && tar czf "$STAGING_DIR/control.tar.gz" .)
(cd "$DATA_DIR" && tar czf "$STAGING_DIR/data.tar.gz" .)

printf "2.0\n" > "$FINAL_DIR/debian-binary"
mv "$STAGING_DIR/control.tar.gz" "$FINAL_DIR/"
mv "$STAGING_DIR/data.tar.gz" "$FINAL_DIR/"

(cd "$FINAL_DIR" && ar rcs "$IPK_FILE" debian-binary control.tar.gz data.tar.gz)

echo "Built: $IPK_FILE"
