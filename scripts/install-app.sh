#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$({
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
})"
REPO_ROOT="$({
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
})"

destination="${1:-$HOME/Applications/Goto.app}"
build_app_script="${GOTO_BUILD_APP_SCRIPT:-$SCRIPT_DIR/build-app.sh}"
ditto_bin="${GOTO_DITTO_BIN:-/usr/bin/ditto}"
open_bin="${GOTO_OPEN_BIN:-/usr/bin/open}"
mkdir -p -- "$REPO_ROOT/build"
products_path="$(mktemp -d "$REPO_ROOT/build/install-products.XXXXXX")"

cleanup() {
  rm -rf -- "$products_path"
}

trap cleanup EXIT

build_app="$($build_app_script "$products_path" | tail -n 1)"

pkill -f "$destination/Contents/MacOS/Goto" >/dev/null 2>&1 || true
mkdir -p -- "$(dirname -- "$destination")"
rm -rf -- "$destination"
"$ditto_bin" "$build_app" "$destination"

"$open_bin" "$destination" >/dev/null 2>&1 || true
printf '%s\n' "$destination"
