#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/generate-app-icon.sh

Generate macOS app icon assets from artwork/goto-app-icon.svg.
Outputs:
  - macos/Resources/Goto.icns
  - build/iconset/
EOF
}

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"
REPO_ROOT="$(
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
)"
SOURCE_SVG="$REPO_ROOT/artwork/goto-app-icon.svg"
BUILD_ROOT="$REPO_ROOT/build/iconset"
ICONSET_DIR="$BUILD_ROOT/Goto.iconset"
MASTER_DIR="$BUILD_ROOT/master"
MASTER_PNG="$MASTER_DIR/goto-app-icon.png"
OUTPUT_ICNS="$REPO_ROOT/macos/Resources/Goto.icns"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

test -f "$SOURCE_SVG"
mkdir -p "$ICONSET_DIR" "$MASTER_DIR" "$(dirname -- "$OUTPUT_ICNS")"

qlmanage -t -s 1024 -o "$MASTER_DIR" "$SOURCE_SVG" >/dev/null 2>&1
mv -f "$MASTER_DIR/$(basename -- "$SOURCE_SVG").png" "$MASTER_PNG"

render_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$MASTER_PNG" --out "$ICONSET_DIR/$name" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
cp "$MASTER_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

printf '%s\n' "$OUTPUT_ICNS"
