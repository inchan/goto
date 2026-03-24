#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P
)"
REPO_ROOT="$(
  cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P
)"

resolve_developer_dir() {
  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    printf '%s\n' "$DEVELOPER_DIR"
    return
  fi

  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    printf '%s\n' "/Applications/Xcode.app/Contents/Developer"
    return
  fi

  xcode-select -p
}

destination="${1:-$REPO_ROOT/build/GotoMenuBar.app}"
package_version="$($SCRIPT_DIR/current-version.sh --bundle)"
developer_dir="$(resolve_developer_dir)"
env DEVELOPER_DIR="$developer_dir" \
  swift build -c release --package-path "$REPO_ROOT/native" --product GotoMenuBar >/dev/null
bin_path="$(
  env DEVELOPER_DIR="$developer_dir" \
    swift build -c release --package-path "$REPO_ROOT/native" --product GotoMenuBar --show-bin-path
)"
binary="$bin_path/GotoMenuBar"

rm -rf -- "$destination"
mkdir -p -- "$destination/Contents/MacOS"

cp "$binary" "$destination/Contents/MacOS/GotoMenuBar"

cat >"$destination/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>GotoMenuBar</string>
  <key>CFBundleIdentifier</key>
  <string>dev.goto.menu-bar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>GotoMenuBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${package_version}</string>
  <key>CFBundleVersion</key>
  <string>${package_version}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

printf '%s\n' "$destination"
