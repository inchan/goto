#!/bin/sh
set -e

SCRIPT_DIR="$({
  cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P
})"
APP_PATH="${GOTO_APP_PATH:-/Applications/Goto.app}"
INSTALL_SHELL_BIN="${GOTO_INSTALL_SHELL_BIN:-$SCRIPT_DIR/install-shell-helper.sh}"
INSTALL_SHELL_SOURCE_ROOT="${GOTO_INSTALL_SHELL_SOURCE_ROOT:-/usr/local/lib/goto}"
OPEN_BIN="${GOTO_OPEN_BIN:-/usr/bin/open}"
STAT_BIN="${GOTO_STAT_BIN:-/usr/bin/stat}"
SU_BIN="${GOTO_SU_BIN:-/usr/bin/su}"
console_user="${GOTO_CONSOLE_USER:-$($STAT_BIN -f %Su /dev/console 2>/dev/null || true)}"
console_home=""

resolve_console_home() {
  if [ -n "${GOTO_CONSOLE_HOME:-}" ]; then
    printf '%s\n' "$GOTO_CONSOLE_HOME"
    return
  fi

  case "$console_user" in
    ""|root|loginwindow)
      return
      ;;
  esac

  "$SU_BIN" -l "$console_user" -c 'printf %s "$HOME"' 2>/dev/null || true
}

list_conflict_app_paths() {
  if [ -n "${GOTO_CONFLICT_APP_PATHS:-}" ]; then
    printf '%s\n' "$GOTO_CONFLICT_APP_PATHS"
    return
  fi

  printf '%s\n' "$APP_PATH"
  if [ -n "$console_home" ]; then
    printf '%s\n' "$console_home/Applications/Goto.app"
  fi
}

remove_conflicting_installs() {
  list_conflict_app_paths | while IFS= read -r path; do
    [ -n "$path" ] || continue
    [ "$path" = "$APP_PATH" ] && continue
    rm -rf -- "$path"
  done
}

install_shell_integration() {
  if [ ! -x "$INSTALL_SHELL_BIN" ]; then
    return 1
  fi

  case "$console_user" in
    ""|root|loginwindow)
      return 1
      ;;
  esac

  "$SU_BIN" -l "$console_user" -c "GOTO_INSTALL_SHELL_SOURCE_ROOT='$INSTALL_SHELL_SOURCE_ROOT' '$INSTALL_SHELL_BIN'" >/dev/null 2>&1
}

launch_app() {
  if [ ! -d "$APP_PATH" ]; then
    return 1
  fi

  case "$console_user" in
    ""|root|loginwindow)
      return 1
      ;;
  esac

  "$SU_BIN" -l "$console_user" -c "'$OPEN_BIN' -gj '$APP_PATH'" >/dev/null 2>&1
}

shell_integration_status="manual"
console_home="$(resolve_console_home)"
remove_conflicting_installs
if install_shell_integration; then
  shell_integration_status="auto"
fi

launch_app || true

echo
echo "goto installed."
if [ "$shell_integration_status" = "auto" ]; then
  echo "Shell integration was installed for $console_user. Open a new shell to use 'goto' cd integration."
else
  echo "Run 'goto-install-shell' to enable shell cd integration."
fi
