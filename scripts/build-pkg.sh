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
app_path="$payload_root/Applications/Goto.app"
cli_root="$payload_root$install_prefix"
cli_bin_root="$payload_root$bin_prefix"

rm -rf -- "$work_root" "${output_path}.sha256"
mkdir -p -- "$payload_root/Applications" "$scripts_root" "$cli_root" "$cli_bin_root" "$(dirname -- "$output_path")"

printf '==> Building Goto.app\n' >&2
finder_build_app="$($SCRIPT_DIR/build-app.sh "$finder_products_root" | tail -n 1)"
ditto "$finder_build_app" "$app_path"

printf '==> Staging CLI payload\n' >&2
mkdir -p -- "$cli_root/bin" "$cli_root/scripts"
cp "$REPO_ROOT/product/cli/package.json" "$cli_root/package.json"
cp -R "$REPO_ROOT/product/cli/bin" "$cli_root/"
cp -R "$REPO_ROOT/product/cli/src" "$cli_root/"
cp -R "$REPO_ROOT/product/cli/shell" "$cli_root/"
cp "$REPO_ROOT/scripts/install-shell.sh" "$cli_root/scripts/install-shell.sh"
cp "$REPO_ROOT/scripts/uninstall.sh" "$cli_root/scripts/uninstall.sh"
chmod +x "$cli_root/bin/goto.js" "$cli_root/scripts/install-shell.sh" "$cli_root/scripts/uninstall.sh"

ln -sfn "$install_prefix/bin/goto.js" "$cli_bin_root/goto"
ln -sfn "$install_prefix/scripts/install-shell.sh" "$cli_bin_root/goto-install-shell"
ln -sfn "$install_prefix/scripts/uninstall.sh" "$cli_bin_root/goto-uninstall"

if [[ -n "${GOTO_CODESIGN_IDENTITY:-}" ]]; then
  printf '==> Signing app bundle\n' >&2
  extension_path="$app_path/Contents/PlugIns/GotoFinderSync.appex"
  codesign --force --timestamp --options runtime --sign "$GOTO_CODESIGN_IDENTITY" \
    --entitlements "$REPO_ROOT/product/macos/GotoFinderSync/GotoFinderSync.entitlements" \
    "$extension_path"
  codesign --force --timestamp --options runtime --sign "$GOTO_CODESIGN_IDENTITY" "$app_path"
  codesign --verify --strict --verbose=2 "$app_path"
fi

cp "$REPO_ROOT/scripts/pkg-postinstall.sh" "$scripts_root/postinstall"
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
