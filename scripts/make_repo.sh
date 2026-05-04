#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-$PROJECT_ROOT/out}"
REPO_DIR="${REPO_DIR:-$PROJECT_ROOT/repo}"

if ! command -v opkg-make-index >/dev/null 2>&1; then
    echo "ERROR: opkg-make-index not found. Install opkg-utils to build a feed." >&2
    exit 1
fi

rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR"

set -- "$SOURCE_DIR"/*.ipk
[ -f "$1" ] || {
    echo "ERROR: no .ipk files found in $SOURCE_DIR" >&2
    exit 1
}

cp "$SOURCE_DIR"/*.ipk "$REPO_DIR"/
opkg-make-index "$REPO_DIR" > "$REPO_DIR/Packages"
gzip -kf "$REPO_DIR/Packages"

echo "Repository prepared in $REPO_DIR"
