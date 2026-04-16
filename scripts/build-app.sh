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
module_cache_path="$REPO_ROOT/build/ModuleCache.noindex"
derived_data_path="$REPO_ROOT/build/DerivedData"
ruby_bin="${GOTO_RUBY_BIN:-ruby}"
xcodebuild_bin="${GOTO_XCODEBUILD_BIN:-xcodebuild}"

"$ruby_bin" "$SCRIPT_DIR/generate_macos_project.rb"
mkdir -p "$module_cache_path" "$derived_data_path"

if [[ -n "${GOTO_DEVELOPMENT_TEAM:-}" ]]; then
  env DEVELOPER_DIR="$developer_dir" \
    "$xcodebuild_bin" \
    -project "$REPO_ROOT/product/macos/Goto.xcodeproj" \
    -scheme Goto \
    -configuration Release \
    -derivedDataPath "$derived_data_path" \
    SYMROOT="$products_path" \
    OBJROOT="$intermediates_path" \
    CLANG_MODULE_CACHE_PATH="$module_cache_path" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$GOTO_DEVELOPMENT_TEAM" \
    build
else
  env DEVELOPER_DIR="$developer_dir" \
    "$xcodebuild_bin" \
    -project "$REPO_ROOT/product/macos/Goto.xcodeproj" \
    -scheme Goto \
    -configuration Release \
    -derivedDataPath "$derived_data_path" \
    SYMROOT="$products_path" \
    OBJROOT="$intermediates_path" \
    CLANG_MODULE_CACHE_PATH="$module_cache_path" \
    build
fi

printf '%s\n' "$products_path/Release/Goto.app"
