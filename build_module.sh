#!/usr/bin/env bash
# Usage: ./build_module.sh [path/to/mitmproxy-ca-cert.pem] [out.zip]
# Names the CA as <subject_hash_old>.0, drops it into the module and zips it.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
CERT=${1:-$HOME/.mitmproxy/mitmproxy-ca-cert.pem}
OUT=${2:-$HERE/user-ca-mitm.zip}
CERTS=$HERE/module/system/etc/security/cacerts

[ -f "$CERT" ] || { echo "CA cert not found: $CERT (run mitmproxy once to generate it)" >&2; exit 1; }

HASH=$(openssl x509 -inform PEM -subject_hash_old -in "$CERT" -noout)
rm -f "$CERTS"/*.0
openssl x509 -inform PEM -in "$CERT" -outform PEM > "$CERTS/$HASH.0"
chmod 644 "$CERTS/$HASH.0"

rm -f "$OUT"
(cd "$HERE/module" && zip -qr "$OUT" . -x '*.keep')
echo "Built $OUT with $HASH.0"
