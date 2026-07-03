#!/usr/bin/env bash
#
# Notarize and staple a DMG (or app) so it passes Gatekeeper on other Macs.
#
# Usage:
#   Scripts/notarize.sh [path-to-dmg] [--profile "RemindAnything-Notary"]
#
# If no path is given, the newest dist/Remind-Anything-*.dmg is used.
# Requires notary credentials stored once with:
#   xcrun notarytool store-credentials "RemindAnything-Notary" \
#     --apple-id you@example.com --team-id TEAMID
set -euo pipefail

cd "$(dirname "$0")/.."

PROFILE="RemindAnything-Notary"
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

# Default to the newest DMG in dist/ when no target was given.
if [[ -z "${TARGET}" ]]; then
  TARGET="$(ls -t dist/Remind-Anything-*.dmg 2>/dev/null | head -n1 || true)"
fi

if [[ -z "${TARGET}" || ! -e "${TARGET}" ]]; then
  echo "✗ No target found. Build a DMG first (Scripts/make_dmg.sh) or pass a path." >&2
  exit 1
fi

echo "▸ Submitting ${TARGET} to Apple notary service (profile: ${PROFILE})…"
# Capture output so we can read the status and submission id. `notarytool
# submit --wait` exits 0 even when the result is "Invalid", so we must inspect
# the status ourselves before attempting to staple.
SUBMIT_OUTPUT="$(xcrun notarytool submit "${TARGET}" \
  --keychain-profile "${PROFILE}" \
  --wait 2>&1)"
echo "${SUBMIT_OUTPUT}"

STATUS="$(echo "${SUBMIT_OUTPUT}" | awk -F': ' '/status:/ {s=$2} END {print s}' | tr -d '[:space:]')"
SUBMISSION_ID="$(echo "${SUBMIT_OUTPUT}" | awk -F': ' '/id:/ {print $2; exit}' | tr -d '[:space:]')"

if [[ "${STATUS}" != "Accepted" ]]; then
  echo "✗ Notarization did not succeed (status: ${STATUS:-unknown})." >&2
  if [[ -n "${SUBMISSION_ID}" ]]; then
    echo "▸ Fetching the notary log for details…" >&2
    xcrun notarytool log "${SUBMISSION_ID}" --keychain-profile "${PROFILE}" >&2 || true
  fi
  exit 1
fi

echo "▸ Stapling the notarization ticket into ${TARGET}…"
xcrun stapler staple "${TARGET}"

echo "▸ Validating with Gatekeeper…"
spctl -a -t open --context context:primary-signature -v "${TARGET}"

echo "✓ Notarized & stapled: ${TARGET}"
