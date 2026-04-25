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
rm_bin="${GOTO_RM_BIN:-rm}"
mkdir -p -- "$REPO_ROOT/build"
products_path="$(mktemp -d "$REPO_ROOT/build/install-products.XXXXXX")"

conflict_app_paths=()
if [[ -n "${GOTO_CONFLICT_APP_PATHS:-}" ]]; then
  while IFS= read -r path; do
    [[ -n "$path" ]] && conflict_app_paths+=("$path")
  done <<< "$GOTO_CONFLICT_APP_PATHS"
else
  if [[ "$destination" == "$HOME/Applications/Goto.app" ]]; then
    conflict_app_paths=("/Applications/Goto.app")
  elif [[ "$destination" == "/Applications/Goto.app" ]]; then
    conflict_app_paths=("$HOME/Applications/Goto.app")
  fi
fi

cleanup() {
  rm -rf -- "$products_path"
}

remove_conflicting_installs() {
  local path

  for path in "${conflict_app_paths[@]-}"; do
    [[ -n "$path" ]] || continue
    [[ "$path" == "$destination" ]] && continue
    pkill -f "$path/Contents/MacOS/Goto" >/dev/null 2>&1 || true
    if ! "$rm_bin" -rf -- "$path"; then
      printf 'warning: could not remove conflicting install: %s\n' "$path" >&2
    fi
  done
}

trap cleanup EXIT

build_app="$($build_app_script "$products_path" | tail -n 1)"

pkill -f "$destination/Contents/MacOS/Goto" >/dev/null 2>&1 || true
remove_conflicting_installs
mkdir -p -- "$(dirname -- "$destination")"
rm -rf -- "$destination"
"$ditto_bin" "$build_app" "$destination"

"$open_bin" "$destination" >/dev/null 2>&1 || true
printf '%s\n' "$destination"
