#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"
REPO_ROOT="$(
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
)"

destination="${1:-$HOME/Applications/Goto.app}"
build_app_script="${GOTO_BUILD_APP_SCRIPT:-$SCRIPT_DIR/build-app.sh}"
extension_id="${GOTO_EXTENSION_ID:-dev.goto.finder.findersync}"
pluginkit_bin="${GOTO_PLUGINKIT_BIN:-/usr/bin/pluginkit}"
pkill_bin="${GOTO_PKILL_BIN:-/usr/bin/pkill}"
killall_bin="${GOTO_KILLALL_BIN:-/usr/bin/killall}"
open_bin="${GOTO_OPEN_BIN:-/usr/bin/open}"
osascript_bin="${GOTO_OSASCRIPT_BIN:-/usr/bin/osascript}"
sleep_bin="${GOTO_SLEEP_BIN:-/bin/sleep}"
ditto_bin="${GOTO_DITTO_BIN:-/usr/bin/ditto}"
rm_bin="${GOTO_RM_BIN:-/bin/rm}"
products_path="$(mktemp -d "$REPO_ROOT/build/install-products.XXXXXX")"
legacy_apps=(
  "${GOTO_LEGACY_MENU_APP:-$HOME/Applications/GotoMenuBar.app}"
  "${GOTO_LEGACY_FINDER_APP:-$HOME/Applications/GotoFinder.app}"
  "/Applications/GotoMenuBar.app"
  "/Applications/GotoFinder.app"
)
failed_legacy_apps=()

list_registered_extensions() {
  "$pluginkit_bin" -m -A -D -v -i "$extension_id" 2>/dev/null |
    sed -nE 's#^.*[[:space:]](/.*GotoFinderSync\.appex)$#\1#p'
}

cleanup_legacy_installations() {
  "$pluginkit_bin" -e ignore -i "$extension_id" >/dev/null 2>&1 || true

  while IFS= read -r extension_path; do
    [[ -n "$extension_path" ]] || continue
    "$pkill_bin" -f "$extension_path/Contents/MacOS/" >/dev/null 2>&1 || true
    "$pluginkit_bin" -r "$extension_path" >/dev/null 2>&1 || true
  done < <(list_registered_extensions)

  for legacy_app in "${legacy_apps[@]}"; do
    [[ "$legacy_app" == "$destination" ]] && continue
    "$pkill_bin" -f "$legacy_app/Contents/MacOS/" >/dev/null 2>&1 || true

    if [[ ! -e "$legacy_app" ]]; then
      continue
    fi

    if ! "$rm_bin" -rf -- "$legacy_app" >/dev/null 2>&1 || [[ -e "$legacy_app" ]]; then
      failed_legacy_apps+=("$legacy_app")
    fi
  done
}

cleanup() {
  rm -rf -- "$products_path"
}

trap cleanup EXIT

build_app="$("$build_app_script" "$products_path" | tail -n 1)"

"$pkill_bin" -f "$destination/Contents/MacOS/Goto" >/dev/null 2>&1 || true
"$pkill_bin" -f "$destination/Contents/PlugIns/GotoFinderSync.appex/Contents/MacOS/GotoFinderSync" >/dev/null 2>&1 || true

cleanup_legacy_installations

mkdir -p -- "$(dirname -- "$destination")"
rm -rf -- "$destination"
"$ditto_bin" "$build_app" "$destination"

extension_path="$destination/Contents/PlugIns/GotoFinderSync.appex"

"$pluginkit_bin" -a "$extension_path" >/dev/null
"$pluginkit_bin" -e use -i "$extension_id" >/dev/null 2>&1 || true
"$pluginkit_bin" -r "$build_app/Contents/PlugIns/GotoFinderSync.appex" >/dev/null 2>&1 || true

"$killall_bin" Finder >/dev/null 2>&1 || true

"$sleep_bin" 2

"$open_bin" "$destination"

"$sleep_bin" 1

# Open extension management so user can re-enable if needed
"$osascript_bin" -e 'tell application "System Preferences" to quit' >/dev/null 2>&1 || true
"$open_bin" "x-apple.systempreferences:com.apple.ExtensionsPreferences"

for legacy_app in "${failed_legacy_apps[@]}"; do
  printf 'Warning: legacy app still present at %s\n' "$legacy_app" >&2
done

printf '%s\n' "$destination"
