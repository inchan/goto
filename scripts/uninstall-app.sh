#!/usr/bin/env bash
set -euo pipefail

destination="${1:-$HOME/Applications/Goto.app}"

pkill -f "$destination/Contents/MacOS/Goto" >/dev/null 2>&1 || true
rm -rf -- "$destination"

printf 'Removed goto app at %s\n' "$destination"
