#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"
REPO_ROOT="$(
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
)"

usage() {
  cat <<EOF
Usage: install.sh [OPTIONS]

Install goto packages from this repository.

Options:
  --cli          Install goto CLI + shell integration
  --menubar      Install goto-menubar app
  --finder       Install goto-finder agent + Finder Sync extension
  --all          Install all three packages (default)
  --help         Show this help

Examples:
  scripts/install.sh --cli              # CLI only
  scripts/install.sh --cli --menubar    # CLI + menu bar
  scripts/install.sh --all              # Everything
EOF
}

install_cli=false
install_menubar=false
install_finder=false

if [[ $# -eq 0 ]]; then
  install_cli=true
  install_menubar=true
  install_finder=true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cli)     install_cli=true ;;
    --menubar) install_menubar=true ;;
    --finder)  install_finder=true ;;
    --all)     install_cli=true; install_menubar=true; install_finder=true ;;
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

if $install_menubar; then
  printf '==> Building goto-menubar\n'
  app="$("$SCRIPT_DIR/build-menu-bar-app.sh" "$HOME/Applications/GotoMenuBar.app")"
  printf '    Installed at %s\n\n' "$app"
fi

if $install_finder; then
  printf '==> Installing goto-finder\n'
  "$SCRIPT_DIR/install-finder.sh"
  printf '    Done.\n\n'
fi

printf 'Installation complete.\n'
