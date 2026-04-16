#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"
REPO_ROOT="$(
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
)"

usage() {
  cat <<'USAGE'
Usage: scripts/package-smoke.sh [PKG_PATH]

Builds an unsigned package when PKG_PATH is omitted, then verifies the package
contains the expected app, CLI payload, shell wrappers, and helper commands.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  printf 'package-smoke: too many arguments\n' >&2
  usage >&2
  exit 2
fi

build_pkg_script="${GOTO_BUILD_PKG_SCRIPT:-$SCRIPT_DIR/build-pkg.sh}"
pkgutil_bin="${GOTO_PKGUTIL_BIN:-pkgutil}"
shasum_bin="${GOTO_SHASUM_BIN:-shasum}"
install_prefix="${GOTO_INSTALL_PREFIX:-/usr/local/lib/goto}"
bin_prefix="${GOTO_BIN_PREFIX:-/usr/local/bin}"

if [[ $# -eq 1 ]]; then
  pkg_path="$1"
else
  pkg_path="$("$build_pkg_script")"
fi

if [[ ! -s "$pkg_path" ]]; then
  printf 'package-smoke: package is missing or empty: %s\n' "$pkg_path" >&2
  exit 1
fi

payload_file="$(mktemp "${TMPDIR:-/tmp}/goto-payload.XXXXXX")"
trap 'rm -f "$payload_file"' EXIT

"$pkgutil_bin" --payload-files "$pkg_path" | sed 's#^\./##' > "$payload_file"

require_payload() {
  local expected="$1"
  if ! grep -Fx -- "$expected" "$payload_file" >/dev/null; then
    printf 'package-smoke: missing payload path: %s\n' "$expected" >&2
    printf 'package-smoke: inspected package: %s\n' "$pkg_path" >&2
    exit 1
  fi
}

install_prefix="${install_prefix#/}"
bin_prefix="${bin_prefix#/}"

require_payload "Applications/Goto.app"
require_payload "Applications/Goto.app/Contents/PlugIns/GotoFinderSync.appex"
require_payload "$install_prefix/bin/goto.js"
require_payload "$install_prefix/src/cli.js"
require_payload "$install_prefix/shell/goto.zsh"
require_payload "$install_prefix/shell/goto.bash"
require_payload "$install_prefix/scripts/install-shell.sh"
require_payload "$install_prefix/scripts/uninstall.sh"
require_payload "$bin_prefix/goto"
require_payload "$bin_prefix/goto-install-shell"
require_payload "$bin_prefix/goto-uninstall"

checksum="$("$shasum_bin" -a 256 "$pkg_path" | awk '{print $1}')"

printf 'Package smoke passed: %s\n' "$pkg_path"
printf 'SHA-256: %s\n' "$checksum"
