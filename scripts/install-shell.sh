#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-shell.sh
  ./scripts/install-shell.sh --shell zsh
  ./scripts/install-shell.sh --shell bash
  ./scripts/install-shell.sh --all

Options:
  --shell <zsh|bash>  Install into one shell config explicitly
  --all               Install into both zsh and bash configs
  --help              Show this help
EOF
}

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"
REPO_ROOT="$(
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
)"
SOURCE_ROOT="${GOTO_INSTALL_SHELL_SOURCE_ROOT:-$REPO_ROOT}"

TARGET_MODE="auto"
TARGET_SHELL=""

while (($# > 0)); do
  case "$1" in
    --shell)
      shift
      if (($# == 0)); then
        printf 'goto install: missing value for --shell\n' >&2
        exit 1
      fi
      TARGET_MODE="single"
      TARGET_SHELL="$1"
      ;;
    --all)
      TARGET_MODE="all"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'goto install: unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

resolve_default_shell() {
  local shell_name
  shell_name="$(basename "${SHELL:-zsh}")"

  case "$shell_name" in
    zsh|bash)
      printf '%s\n' "$shell_name"
      ;;
    *)
      printf 'zsh\n'
      ;;
  esac
}

install_for_shell() {
  local shell_name="$1"
  local rc_file source_file marker_start marker_end temp_file

  case "$shell_name" in
    zsh)
      rc_file="${ZDOTDIR:-$HOME}/.zshrc"
      if [[ -f "$SOURCE_ROOT/product/cli/shell/goto.zsh" ]]; then
        source_file="$SOURCE_ROOT/product/cli/shell/goto.zsh"
      else
        source_file="$SOURCE_ROOT/shell/goto.zsh"
      fi
      ;;
    bash)
      rc_file="$HOME/.bashrc"
      if [[ -f "$SOURCE_ROOT/product/cli/shell/goto.bash" ]]; then
        source_file="$SOURCE_ROOT/product/cli/shell/goto.bash"
      else
        source_file="$SOURCE_ROOT/shell/goto.bash"
      fi
      ;;
    *)
      printf 'goto install: unsupported shell: %s\n' "$shell_name" >&2
      exit 1
      ;;
  esac

  marker_start="# >>> goto >>>"
  marker_end="# <<< goto <<<"

  mkdir -p -- "$(dirname -- "$rc_file")"
  touch "$rc_file"

  if grep -Fq "$source_file" "$rc_file"; then
    printf 'goto already configured in %s\n' "$rc_file"
    return
  fi

  if grep -Fq "$marker_start" "$rc_file"; then
    temp_file="$(mktemp "${TMPDIR:-/tmp}/goto-install.XXXXXX")"
    awk -v marker_start="$marker_start" -v marker_end="$marker_end" '
      $0 == marker_start { in_block = 1; next }
      in_block && $0 == marker_end { in_block = 0; next }
      !in_block { print }
    ' "$rc_file" > "$temp_file"
    mv "$temp_file" "$rc_file"
  fi

  {
    printf '\n'
    printf '%s\n' "$marker_start"
    printf 'source "%s"\n' "$source_file"
    printf '%s\n' "$marker_end"
  } >> "$rc_file"

  printf 'installed goto into %s\n' "$rc_file"
}

case "$TARGET_MODE" in
  auto)
    install_for_shell "$(resolve_default_shell)"
    ;;
  single)
    install_for_shell "$TARGET_SHELL"
    ;;
  all)
    install_for_shell zsh
    install_for_shell bash
    ;;
esac
