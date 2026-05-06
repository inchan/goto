#!/bin/bash
set -euo pipefail

# Goto install 스크립트
# 1. xcodegen + xcodebuild로 앱과 goto binary 빌드
# 2. /Applications/Goto*.app 설치
# 3. ~/.local/bin/goto에 복사 (~/.goto는 사용자 데이터 파일이라 충돌 회피)
# 4. ~/.zshrc / ~/.bashrc에 셸 함수 추가 (멱등)

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen이 필요합니다. 'brew install xcodegen' 후 다시 실행하세요." >&2
    exit 1
fi

echo "[1/4] xcodegen + xcodebuild..."
xcodegen generate > /dev/null
xcodebuild -project Goto.xcodeproj -scheme Goto -configuration Release \
    -derivedDataPath ./build build > /dev/null
xcodebuild -project Goto.xcodeproj -scheme GotoLauncher -configuration Release \
    -derivedDataPath ./build build > /dev/null
xcodebuild -project Goto.xcodeproj -scheme GotoCLI -configuration Release \
    -derivedDataPath ./build build > /dev/null

APP_SRC="./build/Build/Products/Release/Goto.app"
LAUNCHER_SRC="./build/Build/Products/Release/GotoLauncher.app"
APP_DST="/Applications/Goto.app"
LAUNCHER_DST="/Applications/Goto Launcher.app"
BIN_SRC="./build/Build/Products/Release/goto"
BIN_DST_DIR="$HOME/.local/bin"
BIN_DST="$BIN_DST_DIR/goto"

mkdir -p "$BIN_DST_DIR"

echo "[2/4] 앱 설치: $APP_DST, $LAUNCHER_DST"
rm -rf \
    "/Applications/Goto3.app" \
    "/Applications/Goto3 Launcher.app" \
    "/Applications/Goto3Launcher.app" \
    "$APP_DST" \
    "$LAUNCHER_DST"
cp -R "$APP_SRC" "$APP_DST"
cp -R "$LAUNCHER_SRC" "$LAUNCHER_DST"

echo "[3/4] binary 복사: $BIN_DST"
rm -f "$BIN_DST"
cp "$BIN_SRC" "$BIN_DST"
chmod +x "$BIN_DST"

# 셸 함수 마커
MARKER_BEGIN="# >>> goto cli >>>"
MARKER_END="# <<< goto cli <<<"
OLD_MARKER_BEGIN="# >>> goto3 cli >>>"
OLD_MARKER_END="# <<< goto3 cli <<<"

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
        echo "  ! $rc 쓰기 권한 없음 (소유자: $(stat -f '%Su:%Sg' "$rc")). 다음 명령으로 권한 복구 후 재실행:"
        echo "    sudo chown $(whoami):staff $rc && chmod 644 $rc"
        return 1
    fi
    if grep -qF "$OLD_MARKER_BEGIN" "$rc"; then
        local tmp
        tmp=$(mktemp)
        awk -v b="$OLD_MARKER_BEGIN" -v e="$OLD_MARKER_END" '
            $0 == b {skip=1; next}
            $0 == e {skip=0; next}
            !skip {print}
        ' "$rc" > "$tmp"
        mv "$tmp" "$rc"
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
    echo "  → $rc 갱신"
    return 0
}

echo "[4/4] 셸 함수 install"

ZSH_OK=1
BASH_OK=1
[ -e "$HOME/.zshrc" ]  && install_to_rc "$HOME/.zshrc"  || ZSH_OK=$?
[ "$ZSH_OK" -eq 0 ] || install_to_rc "$HOME/.zprofile" || true
[ -e "$HOME/.bashrc" ] && install_to_rc "$HOME/.bashrc" || BASH_OK=$?

cat <<'MSG'

설치 완료.

사용법:
  goto                           인터랙티브 프로젝트 선택
  goto --add <path>              경로 등록
  goto --remove <path>           경로 제거
  goto --add-subdirs <path>      1단계 하위 git 디렉터리 모두 등록
  goto --remove-subdirs <path>   1단계 하위 디렉터리 모두 제거
  goto --help                    도움말

데이터 파일:
  ~/.goto          프로젝트 목록
  ~/.goto_recent   최근 선택한 프로젝트 3개
  ~/.goto_config   정렬 설정

새 셸 세션을 열거나 다음 명령으로 함수를 즉시 적용하세요:
  source ~/.zshrc       (zsh)
  source ~/.zprofile    (zsh fallback)
  source ~/.bashrc      (bash)
MSG
