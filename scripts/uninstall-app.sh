#!/usr/bin/env bash
set -euo pipefail

destination="${1:-$HOME/Applications/Goto.app}"
extension_path="$destination/Contents/PlugIns/GotoFinderSync.appex"

pkill -f "$destination/Contents/MacOS/Goto" >/dev/null 2>&1 || true

if [[ -d "$extension_path" ]]; then
  pluginkit -r "$extension_path" >/dev/null 2>&1 || true
fi

rm -rf -- "$destination"

printf 'Removed goto app at %s\n' "$destination"
