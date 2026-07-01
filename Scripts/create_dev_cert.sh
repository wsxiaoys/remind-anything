#!/usr/bin/env bash
#
# Create a stable, self-signed code-signing certificate for LOCAL DEVELOPMENT.
#
# Why: macOS stores permission grants (Screen Recording, Accessibility,
# Automation) in the TCC database keyed to the app's code-signing identity.
# Ad-hoc signatures ("-") have no stable identity, so TCC falls back to the
# binary's cdhash, which changes on every rebuild — forcing you to re-grant
# permissions each time. Signing with a persistent self-signed certificate
# gives the app a stable identity, so granted permissions survive rebuilds.
#
# Run this ONCE. Afterwards, Scripts/build_app.sh auto-detects and uses it.
#
#   Scripts/create_dev_cert.sh
#
set -euo pipefail

CERT_NAME="RemindAnything Dev"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

if security find-certificate -c "${CERT_NAME}" >/dev/null 2>&1; then
  echo "✓ Certificate \"${CERT_NAME}\" already exists — nothing to do."
  echo "  Sign with:  Scripts/build_app.sh"
  exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "▸ Generating self-signed code-signing certificate \"${CERT_NAME}\"…"

cat > "${WORK_DIR}/openssl.cnf" <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no

[ dn ]
CN = RemindAnything Dev

[ v3 ]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
EOF

# Private key + self-signed cert valid for 10 years.
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${WORK_DIR}/key.pem" \
  -out    "${WORK_DIR}/cert.pem" \
  -days 3650 \
  -config "${WORK_DIR}/openssl.cnf" >/dev/null 2>&1

# Bundle into a PKCS#12 with an empty passphrase for import.
openssl pkcs12 -export \
  -inkey "${WORK_DIR}/key.pem" \
  -in    "${WORK_DIR}/cert.pem" \
  -out   "${WORK_DIR}/identity.p12" \
  -name  "${CERT_NAME}" \
  -passout pass: >/dev/null 2>&1

echo "▸ Importing into login keychain (grant codesign access)…"
# -T authorizes /usr/bin/codesign to use the key without repeated prompts.
security import "${WORK_DIR}/identity.p12" \
  -k "${KEYCHAIN}" \
  -P "" \
  -T /usr/bin/codesign \
  -T /usr/bin/security >/dev/null 2>&1

echo "▸ Trusting the certificate for code signing…"
# Requires an admin password prompt (writes to the trust settings).
sudo security add-trusted-cert -d -r trustRoot \
  -p codeSign \
  -k /Library/Keychains/System.keychain \
  "${WORK_DIR}/cert.pem" >/dev/null 2>&1 || \
  security add-trusted-cert -r trustRoot \
    -p codeSign \
    -k "${KEYCHAIN}" \
    "${WORK_DIR}/cert.pem" >/dev/null 2>&1

echo
echo "✓ Created code-signing identity \"${CERT_NAME}\"."
echo "  Verify with:  security find-identity -v -p codesigning"
echo "  Build with:   Scripts/build_app.sh   (auto-detects this identity)"
echo
echo "NOTE: The FIRST build with this new identity will require you to grant"
echo "      permissions once more. After that, rebuilds keep them."
