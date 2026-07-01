#!/usr/bin/env bash
#
# Create a stable, self-signed code-signing certificate for LOCAL DEVELOPMENT.
#
# Why: macOS stores permission grants (Screen Recording, Accessibility,
# Automation) in the TCC database keyed to the app's code-signing identity
# (its "designated requirement"). Ad-hoc signatures ("-") have no stable
# identity, so TCC falls back to the binary's cdhash, which changes on every
# rebuild — forcing you to re-grant permissions each time. Signing with a
# persistent self-signed certificate gives the app a stable identity, so
# granted permissions survive rebuilds.
#
# Run this ONCE. Afterwards, Scripts/build_app.sh auto-detects and uses it.
#
#   Scripts/create_dev_cert.sh
#
set -euo pipefail

CERT_NAME="RemindAnything Dev"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

# --- already set up? -------------------------------------------------------
# We consider it done only if codesign can actually find a usable identity.
if security find-identity -p codesigning "${KEYCHAIN}" 2>/dev/null | grep -q "${CERT_NAME}"; then
  echo "✓ Code-signing identity \"${CERT_NAME}\" already exists — nothing to do."
  echo "  Build with:  Scripts/build_app.sh"
  exit 0
fi

# Clean up any half-created leftovers from a previous failed run so the
# keychain doesn't accumulate duplicate certs/keys.
if security find-certificate -c "${CERT_NAME}" "${KEYCHAIN}" >/dev/null 2>&1; then
  echo "▸ Removing incomplete previous \"${CERT_NAME}\" certificate…"
  while security delete-certificate -c "${CERT_NAME}" "${KEYCHAIN}" >/dev/null 2>&1; do :; done
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "▸ Generating self-signed code-signing certificate \"${CERT_NAME}\"…"

cat > "${WORK_DIR}/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no

[ dn ]
CN = ${CERT_NAME}

[ v3 ]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
EOF

# Private key + self-signed cert valid for 10 years. Errors are NOT suppressed
# so any failure is visible.
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${WORK_DIR}/key.pem" \
  -out    "${WORK_DIR}/cert.pem" \
  -days 3650 \
  -config "${WORK_DIR}/openssl.cnf"

# Import the private key and certificate SEPARATELY as PEM. This avoids the
# well-known PKCS#12 incompatibility between OpenSSL 3.x and Apple's keychain
# (which silently broke the previous version of this script). The keychain
# pairs them into a usable identity automatically once both are present.
echo "▸ Importing private key into login keychain…"
security import "${WORK_DIR}/key.pem" \
  -k "${KEYCHAIN}" \
  -T /usr/bin/codesign \
  -T /usr/bin/security

echo "▸ Importing certificate into login keychain…"
security import "${WORK_DIR}/cert.pem" \
  -k "${KEYCHAIN}" \
  -T /usr/bin/codesign \
  -T /usr/bin/security

# Allow codesign to use the private key without an interactive GUI prompt.
# Best-effort: needs the login-keychain password, so we let it prompt if run
# interactively; failure here is non-fatal (codesign will just prompt once).
echo "▸ Authorizing codesign to use the key (you may be asked for your login password)…"
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "" "${KEYCHAIN}" >/dev/null 2>&1 || \
  echo "  (skipped automatic authorization — codesign may prompt once on first build)"

# Trust the cert for code signing so it shows up as a *valid* identity.
# Trust is NOT required for TCC persistence or for codesign to sign, but it
# keeps tooling happy. Best-effort; may pop a GUI auth dialog.
echo "▸ Trusting the certificate for code signing (best effort)…"
security add-trusted-cert -r trustRoot -p codeSign -k "${KEYCHAIN}" \
  "${WORK_DIR}/cert.pem" >/dev/null 2>&1 || \
  echo "  (could not set trust automatically — not required, continuing)"

# --- verify ----------------------------------------------------------------
echo "▸ Verifying the identity is usable by codesign…"
if ! security find-identity -p codesigning "${KEYCHAIN}" | grep -q "${CERT_NAME}"; then
  echo "✗ FAILED: \"${CERT_NAME}\" was not registered as a code-signing identity." >&2
  echo "  Keychain contents for debugging:" >&2
  security find-identity "${KEYCHAIN}" >&2 || true
  exit 1
fi

echo
echo "✓ Created code-signing identity \"${CERT_NAME}\"."
security find-identity -p codesigning "${KEYCHAIN}" | grep "${CERT_NAME}" || true
echo
echo "  Next:  Scripts/build_app.sh   (auto-detects and signs with this identity)"
echo
echo "NOTE: The FIRST build with this new identity will require you to grant"
echo "      permissions once more (and possibly approve a keychain prompt for"
echo "      codesign). After that, rebuilds keep the permissions."
