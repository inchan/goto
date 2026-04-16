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
Usage: scripts/verify.sh [--standard|--ci|--help]

Runs the local verification harness.

Modes:
  --standard  Node tests, native typecheck, and native Swift tests (default)
  --ci        Standard checks plus a release app build
  --help      Show this help
USAGE
}

mode="standard"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --standard)
      mode="standard"
      shift
      ;;
    --ci)
      mode="ci"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'verify: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

node_bin="${GOTO_NODE_BIN:-node}"
native_typecheck_script="${GOTO_NATIVE_TYPECHECK_SCRIPT:-$SCRIPT_DIR/typecheck-native.sh}"
native_test_script="${GOTO_NATIVE_TEST_SCRIPT:-$SCRIPT_DIR/test-native.sh}"
build_app_script="${GOTO_BUILD_APP_SCRIPT:-$SCRIPT_DIR/build-app.sh}"

printf '==> Node CLI tests\n' >&2
"$node_bin" --test "$REPO_ROOT"/product/cli/test/*.test.js

printf '==> Native typecheck\n' >&2
"$native_typecheck_script"

printf '==> Native unit tests\n' >&2
"$native_test_script"

if [[ "$mode" == "ci" ]]; then
  printf '==> Native app build\n' >&2
  "$build_app_script" >/dev/null
fi
