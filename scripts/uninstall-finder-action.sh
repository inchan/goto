#!/usr/bin/env bash
set -euo pipefail

destination="${1:-$HOME/Library/Services/Goto in Terminal.workflow}"

rm -rf -- "$destination"

if [[ -x /System/Library/CoreServices/pbs ]]; then
  /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
fi

printf 'Removed Finder action at %s\n' "$destination"
