#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <path-to-pkg>\n' "$0" >&2
  exit 1
fi

pkg_path="$1"
: "${APPLE_API_KEY_ID:?Set APPLE_API_KEY_ID}"
: "${APPLE_API_ISSUER_ID:?Set APPLE_API_ISSUER_ID}"
: "${APPLE_API_PRIVATE_KEY_PATH:?Set APPLE_API_PRIVATE_KEY_PATH}"

xcrun notarytool submit "$pkg_path" \
  --key "$APPLE_API_PRIVATE_KEY_PATH" \
  --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" \
  --wait

xcrun stapler staple "$pkg_path"
spctl -a -vv --type install "$pkg_path"
