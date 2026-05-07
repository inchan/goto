#!/bin/bash
# Goto CLI installer (binary-only, used by GitHub Release zip).
# Installs ./goto into ~/.local/bin and registers a shell function.
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f "./goto" ]; then
    echo "error: ./goto binary not found beside this script." >&2
    exit 1
fi

BIN_DIR="$HOME/.local/bin"
BIN_DST="$BIN_DIR/goto"

mkdir -p "$BIN_DIR"
cp ./goto "$BIN_DST"
chmod +x "$BIN_DST"
echo "[1/2] Installed binary: $BIN_DST"

MARKER_BEGIN="# >>> goto cli >>>"
MARKER_END="# <<< goto cli <<<"

SHELL_FUNC=$(cat <<'EOF'
# >>> goto cli >>>
goto() {
  if [ "$#" -gt 0 ]; then
    "$HOME/.local/bin/goto" "$@"
    return
  fi

  local target
  target=$("$HOME/.local/bin/goto") || return
  if [ -n "$target" ] && [ -d "$target" ]; then
    cd "$target"
  fi
}
# <<< goto cli <<<
EOF
)

install_to_rc() {
    local rc="$1"
    [ -e "$rc" ] || return 0
    if [ ! -w "$rc" ]; then
        echo "  ! $rc is not writable (owner: $(stat -f '%Su:%Sg' "$rc"))." >&2
        echo "    Fix with: sudo chown $(whoami):staff $rc && chmod 644 $rc" >&2
        return 1
    fi
    if grep -qF "$MARKER_BEGIN" "$rc"; then
        local tmp
        tmp=$(mktemp)
        awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
            $0 == b {skip=1; next}
            $0 == e {skip=0; next}
            !skip {print}
        ' "$rc" > "$tmp"
        mv "$tmp" "$rc"
    fi
    printf "\n%s\n" "$SHELL_FUNC" >> "$rc"
    echo "  → updated $rc"
}

echo "[2/2] Registering shell function"

ZSH_OK=1
[ -e "$HOME/.zshrc" ]  && install_to_rc "$HOME/.zshrc"  || ZSH_OK=$?
[ "$ZSH_OK" -eq 0 ] || install_to_rc "$HOME/.zprofile" || true
[ -e "$HOME/.bashrc" ] && install_to_rc "$HOME/.bashrc" || true

cat <<'MSG'

Done.

Open a new shell, or apply the function immediately with:
  source ~/.zshrc       (zsh)
  source ~/.zprofile    (zsh fallback)
  source ~/.bashrc      (bash)

Usage:
  goto                           interactive picker
  goto --add <path>              register a path
  goto --remove <path>           unregister
  goto --add-subdirs <path>      register every git repo one level under <path>
  goto --remove-subdirs <path>   unregister every direct child
  goto --help                    help
MSG
