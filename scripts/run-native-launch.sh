#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"
REPO_ROOT="$(
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
)"

resolve_developer_dir() {
  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    printf '%s\n' "$DEVELOPER_DIR"
    return
  fi

  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    printf '%s\n' "/Applications/Xcode.app/Contents/Developer"
    return
  fi

  xcode-select -p
}

developer_dir="$(resolve_developer_dir)"
binary_path=""

for candidate in \
  "$REPO_ROOT/native/.build/debug/GotoNativeLaunch" \
  "$REPO_ROOT/native/.build/x86_64-apple-macosx/debug/GotoNativeLaunch" \
  "$REPO_ROOT/native/.build/arm64-apple-macosx/debug/GotoNativeLaunch"; do
  if [[ -x "$candidate" ]]; then
    binary_path="$candidate"
    break
  fi
done

if [[ -z "$binary_path" ]]; then
  bin_path="$(
    env DEVELOPER_DIR="$developer_dir" \
      swift build --package-path "$REPO_ROOT/native" --product GotoNativeLaunch --show-bin-path
  )"
  binary_path="$bin_path/GotoNativeLaunch"
fi

exec env DEVELOPER_DIR="$developer_dir" "$binary_path" "$@"
