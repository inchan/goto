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
products_path="${1:-$REPO_ROOT/build/macos-products}"
intermediates_path="$REPO_ROOT/build/macos-obj"

ruby "$SCRIPT_DIR/generate_macos_project.rb"

env DEVELOPER_DIR="$developer_dir" \
  xcodebuild \
  -project "$REPO_ROOT/macos/Goto.xcodeproj" \
  -target Goto \
  -configuration Release \
  SYMROOT="$products_path" \
  OBJROOT="$intermediates_path" \
  build

printf '%s\n' "$products_path/Release/Goto.app"
