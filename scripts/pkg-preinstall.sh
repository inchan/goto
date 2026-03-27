#!/bin/sh
set -e

LEGACY_MENU_APP="${GOTO_LEGACY_MENU_APP:-/Applications/GotoMenuBar.app}"
LEGACY_FINDER_APP="${GOTO_LEGACY_FINDER_APP:-/Applications/GotoFinder.app}"
EXTENSION_PATH="$LEGACY_FINDER_APP/Contents/PlugIns/GotoFinderSync.appex"
EXTENSION_ID="${GOTO_EXTENSION_ID:-dev.goto.finder.findersync}"
PLUGINKIT_BIN="${GOTO_PLUGINKIT_BIN:-/usr/bin/pluginkit}"
PKILL_BIN="${GOTO_PKILL_BIN:-/usr/bin/pkill}"

"$PKILL_BIN" -f "$LEGACY_MENU_APP/Contents/MacOS/" >/dev/null 2>&1 || true
"$PKILL_BIN" -f "$LEGACY_FINDER_APP/Contents/MacOS/" >/dev/null 2>&1 || true
"$PKILL_BIN" -f "$EXTENSION_PATH/Contents/MacOS/" >/dev/null 2>&1 || true

if [ -d "$EXTENSION_PATH" ]; then
  "$PLUGINKIT_BIN" -e ignore -i "$EXTENSION_ID" >/dev/null 2>&1 || true
  "$PLUGINKIT_BIN" -r "$EXTENSION_PATH" >/dev/null 2>&1 || true
fi

rm -rf -- "$LEGACY_MENU_APP" "$LEGACY_FINDER_APP"
