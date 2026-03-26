#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$({
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
})"
REPO_ROOT="$({
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
})"
CLI_PACKAGE_JSON="$REPO_ROOT/product/cli/package.json"
mode="${1:-raw}"

case "$mode" in
  raw|--raw)
    node -p "JSON.parse(require('node:fs').readFileSync(process.argv[1], 'utf8')).version" "$CLI_PACKAGE_JSON"
    ;;
  bundle|--bundle)
    node -p "JSON.parse(require('node:fs').readFileSync(process.argv[1], 'utf8')).version.split('-')[0].split('+')[0]" "$CLI_PACKAGE_JSON"
    ;;
  *)
    printf 'Usage: %s [--raw|--bundle]\n' "$0" >&2
    exit 1
    ;;
esac
