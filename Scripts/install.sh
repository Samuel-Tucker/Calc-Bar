#!/usr/bin/env bash
# Calc Bar installer.
#
# Downloads the latest release, removes the macOS quarantine flag (Calc Bar has
# no Apple Developer account behind it, so the app isn't notarized) and drops it
# into your Applications folder.
#
#   curl -fsSL https://raw.githubusercontent.com/Samuel-Tucker/Calc-Bar/main/Scripts/install.sh | bash
#
# Prefer not to pipe a script into bash? Build from source instead - see the
# README. Local builds aren't quarantined, so they open without any of this.

set -euo pipefail

REPO="Samuel-Tucker/Calc-Bar"
APP_NAME="Calc Bar.app"

DEST="/Applications"
if [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

echo "Looking up the latest Calc Bar release..."
API="https://api.github.com/repos/$REPO/releases/latest"
ZIP_URL="$(curl -fsSL "$API" | grep -Eo 'https://[^"]*-macos\.zip"' | tr -d '"' | head -1 || true)"

if [[ -z "$ZIP_URL" ]]; then
  echo "Couldn't find a published release zip for $REPO." >&2
  echo "Build from source instead - see the README (swift run CalcBar)." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ZIP="$TMP/calc-bar.zip"

echo "Downloading $ZIP_URL"
curl -fsSL "$ZIP_URL" -o "$ZIP"

# Verify the checksum when the release ships one.
if EXPECTED="$(curl -fsSL "$ZIP_URL.sha256" 2>/dev/null | awk '{print $1}')" && [[ -n "${EXPECTED:-}" ]]; then
  ACTUAL="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
  if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    echo "Checksum mismatch - aborting." >&2
    echo "  expected $EXPECTED" >&2
    echo "  actual   $ACTUAL" >&2
    exit 1
  fi
  echo "Checksum verified."
fi

echo "Unpacking..."
mkdir -p "$TMP/unpacked"
ditto -x -k "$ZIP" "$TMP/unpacked"

APP_SRC="$TMP/unpacked/$APP_NAME"
if [[ ! -d "$APP_SRC" ]]; then
  APP_SRC="$(find "$TMP/unpacked" -maxdepth 2 -name '*.app' -type d | head -1)"
fi
if [[ -z "${APP_SRC:-}" || ! -d "$APP_SRC" ]]; then
  echo "Couldn't find the app inside the download." >&2
  exit 1
fi

echo "Installing to ${DEST}..."
rm -rf "${DEST:?}/${APP_NAME:?}"
ditto "$APP_SRC" "$DEST/$APP_NAME"

# Strip the quarantine flag so Gatekeeper doesn't block the unsigned app.
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

echo "Done. Calc Bar is in ${DEST}."
echo "Press Option + C any time to summon the calculator."
open "$DEST/$APP_NAME"
