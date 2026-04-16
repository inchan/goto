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

module_cache_path="$REPO_ROOT/build/ModuleCache.noindex"
swiftpm_cache_path="$REPO_ROOT/build/swiftpm-cache"
swiftpm_config_path="$REPO_ROOT/build/swiftpm-config"
swiftpm_security_path="$REPO_ROOT/build/swiftpm-security"
swiftpm_scratch_path="$REPO_ROOT/product/core/.build"
swift_bin="${GOTO_SWIFT_BIN:-swift}"

mkdir -p \
  "$module_cache_path" \
  "$swiftpm_cache_path" \
  "$swiftpm_config_path" \
  "$swiftpm_security_path" \
  "$swiftpm_scratch_path"

DEVELOPER_DIR="$(resolve_developer_dir)" \
CLANG_MODULE_CACHE_PATH="$module_cache_path" \
  "$swift_bin" test \
    --package-path "$REPO_ROOT/product/core" \
    --cache-path "$swiftpm_cache_path" \
    --config-path "$swiftpm_config_path" \
    --security-path "$swiftpm_security_path" \
    --scratch-path "$swiftpm_scratch_path" \
    --manifest-cache local \
    --disable-sandbox \
    -Xswiftc -module-cache-path \
    -Xswiftc "$module_cache_path" \
    -Xcc "-fmodules-cache-path=$module_cache_path"
