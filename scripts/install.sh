#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$({
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
})"
REPO_ROOT="$({
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
})"

usage() {
  cat <<EOF2
Usage: install.sh [OPTIONS]

Install goto packages from this repository.

Options:
  --cli          Install goto CLI + shell integration
  --app          Install Goto.app
  --all          Install CLI + Goto.app (default)
  --help         Show this help

Examples:
  scripts/install.sh --cli              # CLI only
  scripts/install.sh --cli --app        # CLI + Goto.app
  scripts/install.sh --all              # Everything
EOF2
}

install_cli=false
install_app=false

if [[ $# -eq 0 ]]; then
  install_cli=true
  install_app=true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cli)     install_cli=true ;;
    --app)     install_app=true ;;
    --all)     install_cli=true; install_app=true ;;
    --help)    usage; exit 0 ;;
    *)         printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if $install_cli; then
  printf '==> Installing goto CLI\n'
  "$SCRIPT_DIR/install-shell.sh"
  printf '    Done.\n\n'
fi

if $install_app; then
  printf '==> Installing Goto.app\n'
  app="$($SCRIPT_DIR/install-app.sh "$HOME/Applications/Goto.app")"
  printf '    Installed at %s\n\n' "$app"
fi

printf 'Installation complete.\n'
