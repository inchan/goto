#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"

destination="${1:-$HOME/Library/Services/Goto in Terminal.workflow}"

"$SCRIPT_DIR/render-finder-workflow.sh" "$destination" >/dev/null

if [[ -x /System/Library/CoreServices/pbs ]]; then
  /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
fi

printf 'Installed Finder action at %s\n' "$destination"
