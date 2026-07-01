#!/usr/bin/env bash
#
# Build RemindAnything.app from the Swift package.
#
# Usage:
#   Scripts/build_app.sh [--sign "Developer ID Application: Name (TEAMID)"]
#
# Signing identity resolution (when --sign is NOT passed):
#   1. A local dev certificate named "RemindAnything Dev" if present. This
#      gives the app a STABLE code-signing identity so macOS keeps granted
#      permissions (Screen Recording, Accessibility, Automation) across
#      rebuilds. Create it once with: Scripts/create_dev_cert.sh
#   2. Otherwise, fall back to an ad-hoc signature ("-"). NOTE: ad-hoc builds
#      force you to re-grant permissions on every rebuild.
#
# For distribution (notarization + Homebrew Cask), pass a Developer ID identity.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="RemindAnything"
BUNDLE_NAME="Remind Anything.app"
CONFIG="release"
BUILD_DIR=".build/${CONFIG}"
DIST_DIR="dist"
APP_PATH="${DIST_DIR}/${BUNDLE_NAME}"
DEV_CERT_NAME="RemindAnything Dev"
SIGN_IDENTITY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign) SIGN_IDENTITY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Resolve a default signing identity when none was passed explicitly.
if [[ -z "${SIGN_IDENTITY}" ]]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "${DEV_CERT_NAME}"; then
    SIGN_IDENTITY="${DEV_CERT_NAME}"
    echo "▸ Using stable dev certificate \"${DEV_CERT_NAME}\" (permissions persist across rebuilds)."
  else
    SIGN_IDENTITY="-"
    echo "▸ No dev certificate found — using ad-hoc signature."
    echo "  TIP: run Scripts/create_dev_cert.sh once so macOS keeps permissions across rebuilds."
  fi
fi

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
