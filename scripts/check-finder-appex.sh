#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"
REPO_ROOT="$(
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
)"

app_path="${1:-$REPO_ROOT/build/macos-products/Release/Goto.app}"
codesign_bin="${GOTO_CODESIGN_BIN:-codesign}"
appex_path="$app_path/Contents/PlugIns/GotoFinderSync.appex"

if [[ ! -d "$app_path" ]]; then
  printf 'check-finder-appex: app bundle missing: %s\n' "$app_path" >&2
  exit 1
fi

if [[ ! -d "$appex_path" ]]; then
  printf 'check-finder-appex: Finder appex missing: %s\n' "$appex_path" >&2
  exit 1
fi

entitlements="$($codesign_bin -d --entitlements :- "$appex_path" 2>/dev/null || true)"

if [[ -z "$entitlements" ]]; then
  printf 'check-finder-appex: could not read entitlements for %s\n' "$appex_path" >&2
  exit 1
fi

if [[ "$entitlements" != *"com.apple.security.app-sandbox"* ]]; then
  printf 'check-finder-appex: missing app sandbox entitlement\n' >&2
  exit 1
fi

if [[ "$entitlements" != *"com.apple.security.files.user-selected.read-only"* ]]; then
  printf 'check-finder-appex: missing user-selected.read-only entitlement\n' >&2
  exit 1
fi

printf 'Finder appex check passed: %s\n' "$appex_path"
