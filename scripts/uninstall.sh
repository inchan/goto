#!/bin/bash
set -euo pipefail

MARKER_BEGIN="# >>> goto cli >>>"
MARKER_END="# <<< goto cli <<<"
OLD_MARKER_BEGIN="# >>> goto3 cli >>>"
OLD_MARKER_END="# <<< goto3 cli <<<"

DRY_RUN=0
PURGE=0
ORIGINAL_ARGS=("$@")
FAILED=0

usage() {
  cat <<'EOF'
Usage:
  uninstall.sh [--dry-run] [--purge]

Removes Goto apps, CLI binaries, shell wrappers, and installer receipts.

Options:
  --dry-run   Print what would be removed without changing files.
  --purge     Also remove user data and preferences:
              ~/.goto, ~/.goto_recent, ~/.goto_pinned, ~/.goto_config,
              Goto preferences, and Finder Sync container data.
  --help      Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --purge)
      PURGE=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

SYSTEM_ROOT="${GOTO_UNINSTALL_SYSTEM_ROOT:-/}"
if [ "$SYSTEM_ROOT" != "/" ]; then
  SYSTEM_ROOT="${SYSTEM_ROOT%/}"
fi

if [ "$(id -u)" -ne 0 ] && [ "$DRY_RUN" -eq 0 ] && [ "${GOTO_UNINSTALL_SKIP_SUDO:-0}" -ne 1 ]; then
  exec /usr/bin/sudo "$0" "${ORIGINAL_ARGS[@]}"
fi

system_path() {
  local path="$1"
  if [ "$SYSTEM_ROOT" = "/" ]; then
    printf '%s\n' "$path"
  else
    printf '%s%s\n' "$SYSTEM_ROOT" "$path"
  fi
}

log() {
  printf '%s\n' "$*"
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %q' "$1"
    shift
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  else
    "$@"
  fi
}

remove_path() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    if ! run /bin/rm -rf "$path"; then
      log "warning: failed to remove $path"
      FAILED=1
    fi
  elif [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] missing: $path"
  fi
}

remove_marker_block() {
  local rc="$1"
  local begin="$2"
  local end="$3"

  [ -e "$rc" ] || return 0
  /usr/bin/grep -qF "$begin" "$rc" || return 0

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] remove marker block from $rc: $begin"
    return 0
  fi

  local tmp
  tmp=$(/usr/bin/mktemp "/tmp/goto-uninstall-rc.XXXXXX")
  /usr/bin/awk -v b="$begin" -v e="$end" '
    $0 == b {skip=1; next}
    $0 == e {skip=0; next}
    !skip {print}
  ' "$rc" > "$tmp"
  /bin/cat "$tmp" > "$rc"
  /bin/rm -f "$tmp"
}

clean_rc() {
  local rc="$1"
  remove_marker_block "$rc" "$OLD_MARKER_BEGIN" "$OLD_MARKER_END"
  remove_marker_block "$rc" "$MARKER_BEGIN" "$MARKER_END"
}

forget_receipt() {
  local identifier="$1"

  if /usr/sbin/pkgutil --pkg-info "$identifier" >/dev/null 2>&1; then
    if ! run /usr/sbin/pkgutil --forget "$identifier" >/dev/null; then
      log "warning: failed to forget receipt $identifier"
      FAILED=1
    fi
  elif [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] receipt not found: $identifier"
  fi
}

console_user() {
  if [ -n "${GOTO_UNINSTALL_USER:-}" ]; then
    printf '%s\n' "$GOTO_UNINSTALL_USER"
    return
  fi

  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    printf '%s\n' "$SUDO_USER"
    return
  fi

  /usr/bin/stat -f "%Su" /dev/console 2>/dev/null || true
}

home_for_user() {
  local user="$1"

  if [ -n "${GOTO_UNINSTALL_HOME:-}" ]; then
    printf '%s\n' "$GOTO_UNINSTALL_HOME"
    return
  fi

  if [ -n "$user" ]; then
    /usr/bin/dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2; exit}'
  fi
}

user_name="$(console_user)"
case "$user_name" in
  ""|root|loginwindow|_mbsetupuser)
    user_name=""
    ;;
esac

user_home="$(home_for_user "$user_name")"
if [ -n "$user_home" ] && [ ! -d "$user_home" ]; then
  user_home=""
fi

if [ "$SYSTEM_ROOT" = "/" ]; then
  log "Stopping running Goto processes..."
  run /usr/bin/osascript -e 'tell application id "com.inchan.goto" to quit' >/dev/null 2>&1 || true
  run /usr/bin/pkill -x Goto >/dev/null 2>&1 || true
  run /usr/bin/pkill -x GotoLauncher >/dev/null 2>&1 || true

  if [ -n "$user_name" ]; then
    run /usr/bin/pluginkit -e ignore -i com.inchan.goto.findersync >/dev/null 2>&1 || true
  fi
else
  log "Using system root override: $SYSTEM_ROOT"
fi

log "Removing apps and CLI binaries..."
remove_path "$(system_path "/Applications/Goto.app")"
remove_path "$(system_path "/Applications/Goto Launcher.app")"
remove_path "$(system_path "/Applications/GotoLauncher.app")"
remove_path "$(system_path "/Applications/Goto3.app")"
remove_path "$(system_path "/Applications/Goto3 Launcher.app")"
remove_path "$(system_path "/Applications/Goto3Launcher.app")"
remove_path "$(system_path "/usr/local/bin/goto")"
remove_path "$(system_path "/usr/local/bin/goto-uninstall")"
remove_path "$(system_path "/usr/local/bin/goto3")"
remove_path "$(system_path "/usr/local/bin/goto3-uninstall")"

if [ -n "$user_home" ]; then
  log "Removing shell wrappers and legacy user-local binaries for $user_home..."
  for rc in "$user_home/.zshrc" "$user_home/.zprofile" "$user_home/.bashrc" "$user_home/.bash_profile" "$user_home/.profile"; do
    clean_rc "$rc"
  done

  remove_path "$user_home/.local/bin/goto"
  remove_path "$user_home/.local/bin/goto3"
else
  log "No active user home found; skipped shell wrapper and user-local binary cleanup."
fi

if [ "$SYSTEM_ROOT" = "/" ]; then
  log "Removing installer receipts..."
  forget_receipt "com.inchan.goto.pkg"
  forget_receipt "com.inchan.goto.installer"
  forget_receipt "com.inchan.goto3.pkg"
  forget_receipt "com.inchan.goto3.installer"
else
  log "Skipping installer receipts for system root override."
fi

if [ "$PURGE" -eq 1 ]; then
  if [ -n "$user_home" ]; then
    log "Purging user data and preferences..."
    remove_path "$user_home/.goto"
    remove_path "$user_home/.goto_recent"
    remove_path "$user_home/.goto_pinned"
    remove_path "$user_home/.goto_config"
    remove_path "$user_home/Library/Preferences/com.inchan.goto.plist"
    remove_path "$user_home/Library/Preferences/com.inchan.goto.launcher.plist"
    remove_path "$user_home/Library/Preferences/com.inchan.goto.findersync.plist"
    remove_path "$user_home/Library/Containers/com.inchan.goto.findersync"
    remove_path "$user_home/Library/Application Scripts/com.inchan.goto.findersync"
  else
    log "No active user home found; skipped purge of user data."
  fi
else
  log "User data preserved. Run with --purge to remove ~/.goto* and Goto preferences."
fi

if [ "$FAILED" -eq 0 ]; then
  log "Uninstall complete."
else
  log "Uninstall finished with warnings. Re-run with sudo if protected files remain."
  exit 1
fi
