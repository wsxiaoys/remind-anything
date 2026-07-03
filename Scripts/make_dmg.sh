#!/usr/bin/env bash
#
# Package the built Remind Anything.app into a distributable DMG.
#
# Usage:
#   Scripts/make_dmg.sh
#
# Reads the version from App/Info.plist so the DMG filename stays in sync with
# the bundle. Requires the app to already be built & signed in ./dist
# (run Scripts/build_app.sh --sign ... first) and `create-dmg` installed:
#   brew install create-dmg
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_NAME="Remind Anything.app"
DIST_DIR="dist"
APP_PATH="${DIST_DIR}/${BUNDLE_NAME}"
INFO_PLIST="App/Info.plist"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "✗ ${APP_PATH} not found. Build it first:" >&2
  echo "    Scripts/build_app.sh --sign \"Developer ID Application: NAME (TEAMID)\"" >&2
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "✗ create-dmg not found. Install it:  brew install create-dmg" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}")"
DMG_PATH="${DIST_DIR}/Remind-Anything-${VERSION}.dmg"

echo "▸ Packaging ${BUNDLE_NAME} (v${VERSION}) → ${DMG_PATH}…"
rm -f "${DMG_PATH}"

create-dmg \
  --volname "Remind Anything" \
  --window-size 640 360 \
  --icon "${BUNDLE_NAME}" 160 170 \
  --app-drop-link 480 170 \
  "${DMG_PATH}" \
  "${APP_PATH}"

echo "✓ Built ${DMG_PATH}"
