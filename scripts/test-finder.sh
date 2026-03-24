#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"

destination="${1:-$HOME/Applications/GotoFinder.app}"
installed_app="$("$SCRIPT_DIR/install-finder.sh" "$destination")"
extension_path="$installed_app/Contents/PlugIns/GotoFinderSync.appex"
probe_dir="$(mktemp -d "/tmp/goto finder toolbar.XXXXXX")"

wait_for_process() {
  local pattern="$1"

  for _ in {1..20}; do
    if pgrep -f "$pattern" >/dev/null; then
      return 0
    fi

    sleep 0.25
  done

  return 1
}

cleanup() {
  rm -rf -- "$probe_dir"
}

trap cleanup EXIT

test -d "$installed_app"
test -d "$extension_path"
pluginkit -m -A -D -v -i "dev.goto.finder.findersync" | grep -F -- "$extension_path" >/dev/null
wait_for_process "$installed_app/Contents/MacOS/GotoFinder"
sleep 1

pkill -x Terminal >/dev/null 2>&1 || true
probe_url="$(python3 - <<'PY' "$probe_dir"
import sys, urllib.parse
path = sys.argv[1]
print("goto-finder://open?path=" + urllib.parse.quote(path, safe=""))
PY
)"
open "$probe_url"
sleep 1
pgrep -x Terminal >/dev/null

printf 'Finder agent verified at %s\n' "$installed_app"
