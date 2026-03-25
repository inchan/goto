#!/bin/sh
set -e

FINDER_APP="${GOTO_FINDER_APP:-/Applications/Goto.app}"
EXTENSION_PATH="$FINDER_APP/Contents/PlugIns/GotoFinderSync.appex"
EXTENSION_ID="${GOTO_EXTENSION_ID:-dev.goto.finder.findersync}"
INSTALL_SHELL_BIN="${GOTO_INSTALL_SHELL_BIN:-/usr/local/bin/goto-install-shell}"
PLUGINKIT_BIN="${GOTO_PLUGINKIT_BIN:-/usr/bin/pluginkit}"
KILLALL_BIN="${GOTO_KILLALL_BIN:-/usr/bin/killall}"
STAT_BIN="${GOTO_STAT_BIN:-/usr/bin/stat}"
SU_BIN="${GOTO_SU_BIN:-/usr/bin/su}"
console_user="${GOTO_CONSOLE_USER:-$("$STAT_BIN" -f %Su /dev/console 2>/dev/null || true)}"

enable_finder_extension() {
  if [ -d "$EXTENSION_PATH" ]; then
    "$PLUGINKIT_BIN" -a "$EXTENSION_PATH" >/dev/null || true
    "$PLUGINKIT_BIN" -e use -i "$EXTENSION_ID" >/dev/null 2>&1 || true
  fi

  "$KILLALL_BIN" Finder >/dev/null 2>&1 || true
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

  "$SU_BIN" -l "$console_user" -c "'$INSTALL_SHELL_BIN'" >/dev/null 2>&1
}

enable_finder_extension

shell_integration_status="manual"
if install_shell_integration; then
  shell_integration_status="auto"
fi

echo
echo "goto installed."
if [ "$shell_integration_status" = "auto" ]; then
  echo "Shell integration was installed for $console_user. Open a new shell to use 'goto' cd integration."
else
  echo "Run 'goto-install-shell' to enable shell cd integration."
fi
echo "If Finder Sync is disabled, re-enable goto in System Settings > Extensions > Finder Extensions."
