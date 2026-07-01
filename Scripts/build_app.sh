#!/usr/bin/env bash
#
# Build RemindAnything.app from the Swift package.
#
# Usage:
#   Scripts/build_app.sh [--sign "Developer ID Application: Name (TEAMID)"]
#
# Without --sign, an ad-hoc signature is applied so the app can run locally.
# For distribution (notarization + Homebrew Cask), pass a Developer ID identity.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="RemindAnything"
BUNDLE_NAME="Remind Anything.app"
CONFIG="release"
BUILD_DIR=".build/${CONFIG}"
DIST_DIR="dist"
APP_PATH="${DIST_DIR}/${BUNDLE_NAME}"
SIGN_IDENTITY="-"   # ad-hoc by default

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign) SIGN_IDENTITY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "▸ Building ${APP_NAME} (${CONFIG})…"
swift build -c "${CONFIG}"

echo "▸ Assembling ${BUNDLE_NAME}…"
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"
cp "App/Info.plist" "${APP_PATH}/Contents/Info.plist"

echo "▸ Signing (identity: ${SIGN_IDENTITY})…"
codesign --force --deep \
  --options runtime \
  --entitlements "App/RemindAnything.entitlements" \
  --sign "${SIGN_IDENTITY}" \
  "${APP_PATH}"

echo "✓ Built ${APP_PATH}"
echo
echo "Run it with:  open \"${APP_PATH}\""
