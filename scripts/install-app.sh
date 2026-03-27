#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"
REPO_ROOT="$(
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
)"

destination="${1:-$HOME/Applications/Goto.app}"
products_path="$(mktemp -d "$REPO_ROOT/build/install-products.XXXXXX")"

cleanup() {
  rm -rf -- "$products_path"
}

trap cleanup EXIT

build_app="$("$SCRIPT_DIR/build-app.sh" "$products_path" | tail -n 1)"

pkill -f "$destination/Contents/MacOS/Goto" >/dev/null 2>&1 || true
pkill -f "$destination/Contents/PlugIns/GotoFinderSync.appex/Contents/MacOS/GotoFinderSync" >/dev/null 2>&1 || true

mkdir -p -- "$(dirname -- "$destination")"
rm -rf -- "$destination"
ditto "$build_app" "$destination"

extension_path="$destination/Contents/PlugIns/GotoFinderSync.appex"

pluginkit -a "$extension_path" >/dev/null
pluginkit -e use -i "dev.goto.finder.findersync" >/dev/null 2>&1 || true
pluginkit -r "$build_app/Contents/PlugIns/GotoFinderSync.appex" >/dev/null 2>&1 || true

killall Finder >/dev/null 2>&1 || true

sleep 2

open "$destination"

sleep 1

# Open extension management so user can re-enable if needed
osascript -e 'tell application "System Preferences" to quit' >/dev/null 2>&1 || true
open "x-apple.systempreferences:com.apple.ExtensionsPreferences"

printf '%s\n' "$destination"
