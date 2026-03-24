#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$({
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
})"
REPO_ROOT="$({
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
})"

version="$($SCRIPT_DIR/current-version.sh --raw)"
bundle_version="$($SCRIPT_DIR/current-version.sh --bundle)"
output_path="${1:-$REPO_ROOT/build/goto-$version.pkg}"
install_prefix="${GOTO_INSTALL_PREFIX:-/usr/local/lib/goto}"
bin_prefix="${GOTO_BIN_PREFIX:-/usr/local/bin}"
work_root="$REPO_ROOT/build/pkg"
payload_root="$work_root/root"
scripts_root="$work_root/scripts"
finder_products_root="$work_root/finder-products"
menu_app_path="$payload_root/Applications/GotoMenuBar.app"
finder_app_path="$payload_root/Applications/GotoFinder.app"
cli_root="$payload_root$install_prefix"
cli_bin_root="$payload_root$bin_prefix"

rm -rf -- "$work_root" "${output_path}.sha256"
mkdir -p -- "$payload_root/Applications" "$scripts_root" "$cli_root" "$cli_bin_root" "$(dirname -- "$output_path")"

printf '==> Building GotoMenuBar.app\n' >&2
"$SCRIPT_DIR/build-menu-bar-app.sh" "$menu_app_path" >/dev/null

printf '==> Building GotoFinder.app\n' >&2
finder_build_app="$($SCRIPT_DIR/build-finder.sh "$finder_products_root" | tail -n 1)"
ditto "$finder_build_app" "$finder_app_path"

printf '==> Staging CLI payload\n' >&2
mkdir -p -- "$cli_root/bin" "$cli_root/scripts"
cp "$REPO_ROOT/package.json" "$cli_root/package.json"
cp -R "$REPO_ROOT/bin" "$cli_root/"
cp -R "$REPO_ROOT/src" "$cli_root/"
cp -R "$REPO_ROOT/shell" "$cli_root/"
cp "$REPO_ROOT/scripts/install-shell.sh" "$cli_root/scripts/install-shell.sh"
chmod +x "$cli_root/bin/goto.js" "$cli_root/scripts/install-shell.sh"

ln -sfn "$install_prefix/bin/goto.js" "$cli_bin_root/goto"
ln -sfn "$install_prefix/scripts/install-shell.sh" "$cli_bin_root/goto-install-shell"

if [[ -n "${GOTO_CODESIGN_IDENTITY:-}" ]]; then
  printf '==> Signing app bundles\n' >&2
  extension_path="$finder_app_path/Contents/PlugIns/GotoFinderSync.appex"
  codesign --force --timestamp --options runtime --sign "$GOTO_CODESIGN_IDENTITY" \
    --entitlements "$REPO_ROOT/macos/GotoFinderSync/GotoFinderSync.entitlements" \
    "$extension_path"
  codesign --force --timestamp --options runtime --sign "$GOTO_CODESIGN_IDENTITY" "$finder_app_path"
  codesign --force --timestamp --options runtime --sign "$GOTO_CODESIGN_IDENTITY" "$menu_app_path"
  codesign --verify --strict --verbose=2 "$finder_app_path"
  codesign --verify --strict --verbose=2 "$menu_app_path"
fi

cat > "$scripts_root/postinstall" <<'POSTINSTALL'
#!/bin/sh
set -e

FINDER_APP="/Applications/GotoFinder.app"
EXTENSION_PATH="$FINDER_APP/Contents/PlugIns/GotoFinderSync.appex"

if [ -d "$EXTENSION_PATH" ]; then
  /usr/bin/pluginkit -a "$EXTENSION_PATH" >/dev/null || true
  /usr/bin/pluginkit -e use -i "dev.goto.finder.findersync" >/dev/null 2>&1 || true
fi

/usr/bin/killall Finder >/dev/null 2>&1 || true

echo
echo "goto installed."
echo "Run 'goto-install-shell' to enable shell cd integration."
echo "If Finder Sync is disabled, re-enable goto in System Settings > Extensions > Finder Extensions."
POSTINSTALL
chmod +x "$scripts_root/postinstall"

pkgbuild_cmd=(
  pkgbuild
  --root "$payload_root"
  --scripts "$scripts_root"
  --identifier dev.goto.installer
  --version "$bundle_version"
  --install-location /
)

if [[ -n "${GOTO_INSTALLER_IDENTITY:-}" ]]; then
  pkgbuild_cmd+=(--sign "$GOTO_INSTALLER_IDENTITY")
fi

pkgbuild_cmd+=("$output_path")

printf '==> Building package %s\n' "$output_path" >&2
"${pkgbuild_cmd[@]}" >/dev/null
printf '%s\n' "$output_path"
