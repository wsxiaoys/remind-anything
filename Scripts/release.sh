#!/usr/bin/env bash
#
# One-command notarized release: build (signed) → DMG → notarize → staple →
# print the sha256 you paste into the Homebrew Cask.
#
# Usage:
#   Scripts/release.sh --sign "Developer ID Application: NAME (TEAMID)" \
#                      [--profile "RemindAnything-Notary"]
#
# Prerequisites:
#   - A "Developer ID Application" certificate in the keychain.
#   - Notary credentials stored: see Scripts/notarize.sh.
#   - create-dmg installed: brew install create-dmg
#
# See docs/publishing.md for the full flow (GitHub Release + Cask update).
set -euo pipefail

cd "$(dirname "$0")/.."

SIGN_IDENTITY=""
PROFILE="RemindAnything-Notary"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign) SIGN_IDENTITY="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "${SIGN_IDENTITY}" ]]; then
  echo "✗ --sign is required for a release build." >&2
  echo "    Scripts/release.sh --sign \"Developer ID Application: NAME (TEAMID)\"" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" App/Info.plist)"
DMG_PATH="dist/Remind-Anything-${VERSION}.dmg"

echo "════════════════════════════════════════════"
echo " Releasing Remind Anything v${VERSION}"
echo "════════════════════════════════════════════"

echo "▸ [1/4] Building & signing…"
Scripts/build_app.sh --sign "${SIGN_IDENTITY}"

echo "▸ [2/4] Packaging DMG…"
Scripts/make_dmg.sh

echo "▸ [3/4] Notarizing & stapling…"
Scripts/notarize.sh "${DMG_PATH}" --profile "${PROFILE}"

echo "▸ [4/4] Computing checksum…"
SHA256="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"

echo
echo "✓ Release artifact ready: ${DMG_PATH}"
echo
echo "Next steps (see docs/publishing.md):"
echo "  1. gh release create \"v${VERSION}\" \"${DMG_PATH}\" --title \"Remind Anything ${VERSION}\""
echo "  2. Update Casks/remind-anything.rb:"
echo "       version \"${VERSION}\""
echo "       sha256  \"${SHA256}\""
