#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  goto-uninstall [--purge]

Options:
  --purge    Also remove ~/.goto and ~/.goto-settings
  --help     Show this help
EOF
}

INSTALL_PREFIX="${GOTO_INSTALL_PREFIX:-/usr/local/lib/goto}"
BIN_PREFIX="${GOTO_BIN_PREFIX:-/usr/local/bin}"
APP_PATH="${GOTO_APP_PATH:-/Applications/Goto.app}"
LEGACY_MENU_APP_PATH="${GOTO_LEGACY_MENU_APP_PATH:-/Applications/GotoMenuBar.app}"
LEGACY_FINDER_APP_PATH="${GOTO_LEGACY_FINDER_APP_PATH:-/Applications/GotoFinder.app}"
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/GotoFinderSync.appex"
EXTENSION_ID="${GOTO_EXTENSION_ID:-dev.goto.finder.findersync}"
INSTALL_RECEIPT_ID="${GOTO_INSTALL_RECEIPT_ID:-dev.goto.installer}"
PLUGINKIT_BIN="${GOTO_PLUGINKIT_BIN:-/usr/bin/pluginkit}"
PKGUTIL_BIN="${GOTO_PKGUTIL_BIN:-/usr/sbin/pkgutil}"
PKILL_BIN="${GOTO_PKILL_BIN:-/usr/bin/pkill}"
KILLALL_BIN="${GOTO_KILLALL_BIN:-/usr/bin/killall}"
DSCL_BIN="${GOTO_DSCL_BIN:-/usr/bin/dscl}"
STAT_BIN="${GOTO_STAT_BIN:-/usr/bin/stat}"
purge_user_data=false

while (($# > 0)); do
  case "$1" in
    --purge)
      purge_user_data=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'goto uninstall: unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "${GOTO_UNINSTALL_ALLOW_NON_ROOT:-0}" != "1" && "${EUID}" -ne 0 ]]; then
  printf 'goto uninstall: run with sudo so installed apps and /usr/local payloads can be removed\n' >&2
  exit 1
fi

resolve_target_user() {
  if [[ -n "${GOTO_TARGET_USER:-}" ]]; then
    printf '%s\n' "$GOTO_TARGET_USER"
    return
  fi

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s\n' "$SUDO_USER"
    return
  fi

  "$STAT_BIN" -f '%Su' /dev/console 2>/dev/null || true
}

resolve_target_home() {
  local target_user="$1"

  if [[ -n "${GOTO_TARGET_HOME:-}" ]]; then
    printf '%s\n' "$GOTO_TARGET_HOME"
    return
  fi

  if [[ -z "$target_user" || "$target_user" == "root" || "$target_user" == "loginwindow" ]]; then
    return
  fi

  "$DSCL_BIN" . -read "/Users/$target_user" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
}

remove_shell_integration() {
  local rc_file="$1"
  local temp_file

  [[ -f "$rc_file" ]] || return 0

  temp_file="$(mktemp "${TMPDIR:-/tmp}/goto-uninstall.XXXXXX")"
  awk -v installed_source_prefix="$INSTALL_PREFIX/shell/goto." '
    $0 == "# >>> goto >>>" {
      in_block = 1
      block_count = 1
      block[block_count] = $0
      block_matches_install = 0
      next
    }

    in_block {
      block_count++
      block[block_count] = $0

      if (index($0, installed_source_prefix) > 0) {
        block_matches_install = 1
      }

      if ($0 == "# <<< goto <<<") {
        if (!block_matches_install) {
          for (i = 1; i <= block_count; i++) {
            print block[i]
          }
        }

        in_block = 0
        block_count = 0
        delete block
      }
      next
    }

    index($0, installed_source_prefix) == 0 {
      print
    }

    END {
      if (in_block && !block_matches_install) {
        for (i = 1; i <= block_count; i++) {
          print block[i]
        }
      }
    }
  ' "$rc_file" > "$temp_file"
  mv "$temp_file" "$rc_file"
}

target_user="$(resolve_target_user)"
target_home="$(resolve_target_home "$target_user")"
registry_path="${GOTO_REGISTRY_PATH:-${target_home:+$target_home/.goto}}"
settings_path="${GOTO_SETTINGS_PATH:-${target_home:+$target_home/.goto-settings}}"

if [[ -n "$target_home" ]]; then
  remove_shell_integration "$target_home/.zshrc"
  remove_shell_integration "$target_home/.bashrc"
fi

"$PKILL_BIN" -f "$APP_PATH/Contents/MacOS/" >/dev/null 2>&1 || true
"$PKILL_BIN" -f "$LEGACY_MENU_APP_PATH/Contents/MacOS/" >/dev/null 2>&1 || true
"$PKILL_BIN" -f "$LEGACY_FINDER_APP_PATH/Contents/MacOS/" >/dev/null 2>&1 || true

"$PLUGINKIT_BIN" -e ignore -i "$EXTENSION_ID" >/dev/null 2>&1 || true
if [[ -d "$EXTENSION_PATH" ]]; then
  "$PLUGINKIT_BIN" -r "$EXTENSION_PATH" >/dev/null 2>&1 || true
fi

rm -rf -- "$APP_PATH" "$LEGACY_MENU_APP_PATH" "$LEGACY_FINDER_APP_PATH" "$INSTALL_PREFIX"
rm -f -- "$BIN_PREFIX/goto" "$BIN_PREFIX/goto-install-shell" "$BIN_PREFIX/goto-uninstall"

"$PKGUTIL_BIN" --forget "$INSTALL_RECEIPT_ID" >/dev/null 2>&1 || true
"$KILLALL_BIN" Finder >/dev/null 2>&1 || true

if $purge_user_data; then
  [[ -n "${registry_path:-}" ]] && rm -f -- "$registry_path"
  [[ -n "${settings_path:-}" ]] && rm -f -- "$settings_path"
fi

echo
echo "goto uninstalled."
if $purge_user_data; then
  echo "Removed user data files."
else
  echo "Preserved user data files. Re-run with --purge to remove ~/.goto and ~/.goto-settings."
fi
