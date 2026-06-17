#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd -P)"

export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: $0 vX.Y.Z" >&2
  exit 64
fi

PKG_VERSION="${VERSION#v}"
if ! [[ "$PKG_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be vMAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH: $VERSION" >&2
  exit 64
fi

absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$REPO_ROOT" "$1" ;;
  esac
}

BUILD_PRODUCTS_DIR="$(absolute_path "${BUILD_PRODUCTS_DIR:-./build/Build/Products/Release}")"
DIST_DIR="$(absolute_path "${DIST_DIR:-./dist}")"
PKG_ROOT="$DIST_DIR/pkg-root"
PKG_WORK="$DIST_DIR/pkg-work"
PKG_SCRIPTS="$PKG_WORK/scripts"
COMPONENT_PKG="$PKG_WORK/GotoComponent.pkg"
PRODUCT_PKG="$DIST_DIR/Goto-$VERSION.pkg"

APP_SRC="$BUILD_PRODUCTS_DIR/Goto.app"
LAUNCHER_SRC="$BUILD_PRODUCTS_DIR/GotoLauncher.app"
CLI_SRC="$BUILD_PRODUCTS_DIR/goto"

for required in "$APP_SRC" "$LAUNCHER_SRC" "$CLI_SRC"; do
  if [ ! -e "$required" ]; then
    echo "error: missing build artifact: $required" >&2
    exit 66
  fi
done

strip_appledouble_files() {
  local package="$1"
  local expanded="$PKG_WORK/component-expanded"
  local payload="$PKG_WORK/payload-expanded"
  local cleaned="$PKG_WORK/GotoComponent-clean.pkg"

  rm -rf "$expanded" "$payload" "$cleaned"
  /usr/sbin/pkgutil --expand "$package" "$expanded"

  if [ -f "$expanded/Payload" ]; then
    mkdir -p "$payload"
    (
      cd "$payload"
      /usr/bin/gzip -dc "$expanded/Payload" | /usr/bin/cpio -idm 2>/dev/null
    )
    /usr/bin/find "$payload" -name '._*' -delete
    payload_files=$(cd "$payload" && /usr/bin/find . -print | /usr/bin/wc -l | /usr/bin/tr -d ' ')
    payload_kbytes=$(/usr/bin/du -sk "$payload" | /usr/bin/awk '{print $1}')
    /usr/bin/mkbom "$payload" "$expanded/Bom"
    (
      cd "$payload"
      COPYFILE_DISABLE=1 /usr/bin/find . -print | LC_ALL=C /usr/bin/sort | /usr/bin/cpio -o --format odc 2>/dev/null | /usr/bin/gzip -c > "$expanded/Payload"
    )
    /usr/bin/perl -0pi -e "s/<payload numberOfFiles=\"\\d+\" installKBytes=\"\\d+\"\\/>/<payload numberOfFiles=\"$payload_files\" installKBytes=\"$payload_kbytes\"\\/>/" "$expanded/PackageInfo"
  fi

  if [ -d "$expanded/Scripts" ]; then
    /usr/bin/find "$expanded/Scripts" -name '._*' -delete
  fi

  /usr/sbin/pkgutil --flatten "$expanded" "$cleaned"
  /bin/mv "$cleaned" "$package"
}

rm -rf "$PKG_ROOT" "$PKG_WORK" "$PRODUCT_PKG"
mkdir -p "$PKG_ROOT/Applications" "$PKG_ROOT/usr/local/bin" "$PKG_SCRIPTS" "$DIST_DIR"

/usr/bin/ditto --noextattr --norsrc "$APP_SRC" "$PKG_ROOT/Applications/Goto.app"
/usr/bin/ditto --noextattr --norsrc "$LAUNCHER_SRC" "$PKG_ROOT/Applications/Goto Launcher.app"
/usr/bin/install -m 0755 "$CLI_SRC" "$PKG_ROOT/usr/local/bin/goto"
/usr/bin/install -m 0755 "scripts/uninstall.sh" "$PKG_ROOT/usr/local/bin/goto-uninstall"

for script in preinstall postinstall; do
  /bin/cp "installer/scripts/$script" "$PKG_SCRIPTS/$script"
  /bin/chmod 0755 "$PKG_SCRIPTS/$script"
done

/usr/bin/xattr -cr "$PKG_ROOT" "$PKG_SCRIPTS" 2>/dev/null || true

/usr/bin/pkgbuild \
  --root "$PKG_ROOT" \
  --component-plist "installer/components.plist" \
  --scripts "$PKG_SCRIPTS" \
  --identifier "com.inchan.goto.pkg" \
  --version "$PKG_VERSION" \
  --install-location "/" \
  "$COMPONENT_PKG"

strip_appledouble_files "$COMPONENT_PKG"

/usr/bin/productbuild \
  --package "$COMPONENT_PKG" \
  --identifier "com.inchan.goto.installer" \
  --version "$PKG_VERSION" \
  "$PRODUCT_PKG"

echo "Built $PRODUCT_PKG"
