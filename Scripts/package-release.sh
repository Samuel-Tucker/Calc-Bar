#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.1.0}"
APP_DIR="$ROOT_DIR/.build/Calc Bar.app"
DIST_DIR="$ROOT_DIR/.build/dist"
ZIP_PATH="$DIST_DIR/Calc-Bar-$VERSION-macos.zip"

"$ROOT_DIR/Scripts/build-app.sh" >/dev/null

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

echo "$ZIP_PATH"
