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
module_cache_path="$REPO_ROOT/build/ModuleCache.noindex"
xcrun_bin="${GOTO_XCRUN_BIN:-xcrun}"
swiftc_bin="${GOTO_SWIFTC_BIN:-swiftc}"

mkdir -p "$module_cache_path"

SDK_PATH="$(DEVELOPER_DIR="$developer_dir" "$xcrun_bin" --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx13.0"

DEVELOPER_DIR="$developer_dir" \
CLANG_MODULE_CACHE_PATH="$module_cache_path" \
  "$swiftc_bin" \
  -sdk "$SDK_PATH" \
  -target "$TARGET" \
  -module-cache-path "$module_cache_path" \
  -typecheck \
  "$REPO_ROOT"/product/core/Sources/GotoNativeCore/*.swift
