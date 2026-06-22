# Goto

Finder Sync Extension 기반 터미널 열기 앱입니다.

## 설치 (Release)

GitHub Releases에서 `Goto-vX.Y.Z.dmg`를 내려받습니다.

DMG를 열고 `Install Goto.pkg`를 실행하면 다음 항목이 한 번에 설치됩니다.

- `/Applications/Goto.app`
- `/Applications/Goto Launcher.app`
- `/usr/local/bin/goto`
- `/usr/local/bin/goto-uninstall`
- 현재 로그인 사용자의 셸 설정에 `goto()` wrapper 함수

처음 실행 시 macOS Gatekeeper가 "확인되지 않은 개발자" 경고를 띄울 수 있습니다. 다음 둘 중 하나로 우회하세요.

```sh
# 방법 1: Finder에서 Install Goto.pkg 또는 Goto.app 우클릭 → 열기 (한 번만 승인하면 됩니다).
# 방법 2: quarantine 속성 제거.
sudo xattr -dr com.apple.quarantine /Applications/Goto.app "/Applications/Goto Launcher.app" /usr/local/bin/goto
```

## 동작

- Finder Sync 도구막대의 `Goto` 버튼을 클릭하면 `Open in Terminal` 메뉴가 열립니다.
  - `Open in Terminal` — 현재 Finder 위치를 설정한 기본 터미널로 엽니다.
- Finder 도구막대에 `Goto Launcher.app`을 직접 끌어다 놓고 클릭하면 메뉴 없이 기본 터미널이 바로 열립니다.
- 설정 화면에서 기본 터미널과 "이미 실행 중일 때 새 탭/창" 동작을 선택합니다. Ghostty가 설치되어 있으면 선택지에 표시됩니다.
- 터미널 앱이 이미 열려 있으면 설정값에 따라 새 탭 또는 새 창으로 엽니다. 열려 있지 않으면 항상 새 창을 엽니다.
- Terminal.app의 새 탭 열기는 macOS Accessibility 권한이 필요합니다. 권한이 없으면 새 창으로 엽니다.
- Finder에서 파일/폴더를 우클릭했을 때도 같은 메뉴 항목을 제공합니다.

Finder Sync 도구막대 버튼은 공개 API에서 왼쪽 클릭, 오른쪽 클릭, 롱클릭을 구분하지 않습니다.
Finder Sync는 도구막대 버튼 클릭 시 메뉴만 요청하므로, 진짜 한 번 클릭 실행은 `Goto Launcher.app`을 Finder 도구막대에 직접 추가해서 사용합니다.

## CLI (`goto`)

터미널 어디에서든 사용할 수 있는 인터랙티브 프로젝트 네비게이터입니다.

```sh
goto                              # 등록된 프로젝트 리스트 → ↑↓ 이동, Enter 선택, 키 입력 시 자동 필터, Ctrl+P 핀 토글, ESC/Ctrl+Q 취소
goto --add, -a <path>             # 경로 등록
goto --remove, -r <path>          # 경로 제거
goto --add-subdirs, -A <path>     # 1단계 하위 git 디렉터리 모두 등록 (이후 자동 동기화 대상으로 감시)
goto --remove-subdirs, -R <path>  # 1단계 하위 디렉터리 모두 제거
goto --unwatch, -U <path>         # 감시 해제 (등록된 프로젝트는 유지)
goto --sync, -S                   # 감시 중인 폴더 동기화
goto --pin, -p <path>             # 프로젝트 핀 고정 (최상단)
goto --unpin, -u <path>           # 프로젝트 핀 해제
goto --help, -h                   # 도움말
```

- `--add-subdirs`로 등록한 상위 폴더는 감시 대상으로 기억되어(`~/.goto_watched`) 이후 자동 동기화됩니다. 인터랙티브 모드 진입 시 감시 폴더를 백그라운드로 동기화하며(반영은 다음 실행 때), `--sync`로 직접 실행할 수도 있습니다. 추가 기준은 직속 하위 git 루트, 제거 기준은 폴더가 물리적으로 삭제된 경우입니다.
- 등록 데이터: `~/.goto` (한 줄 한 path, 사용자가 직접 편집 가능)
- 핀 고정한 프로젝트는 `~/.goto_pinned`에 저장되며 인터랙티브 리스트와 메뉴바의 **최상단**에 📌 마커와 함께 표시됩니다. 인터랙티브 리스트에서 `Ctrl+P`로 토글, 메뉴바에서는 ⌥ 키를 누른 채 항목 위에 마우스를 올리면 "핀 고정/해제" 항목이 alternate로 표시됩니다.
- 최근 선택한 프로젝트는 `~/.goto_recent`에 저장되고, 핀 고정 영역 바로 아래에 표시됩니다(핀과 중복 시 핀 영역에서만 표시). 표시 개수는 기본 **5개**이며 CLI settings의 `최근 항목 개수`(Space: 0/1/3/5/10 순환, Enter: 직접 입력) 또는 macOS 앱 환경설정창의 `최근 개수` 콤보박스(선택 또는 직접 입력)에서 `0~50` 범위로 지정할 수 있습니다.
- 정렬 설정은 `~/.goto_config`에 저장됩니다. CLI settings에서 핀 정렬, 상위 폴더 정렬, 프로젝트 정렬을 각각 변경할 수 있습니다. 핀 정렬 기본값은 "추가순"(insertion order).
- 인터랙티브 선택은 **현재 셸에서 `cd`**합니다. 설치 과정이 셸 시작 파일에 추가한 `goto()` wrapper가 binary stdout을 받아 `cd` 실행
- 비TTY(파이프) 호출 시 리스트를 stdout 한 줄씩 출력 (`goto | grep ...` 가능)

### 설치

Release 설치는 `Install Goto.pkg`가 자동으로 처리합니다. 설치 직후 새 셸 세션을 열거나 다음 명령으로 함수를 즉시 적용하세요.

```sh
source ~/.zshrc       # zsh
source ~/.bash_profile 2>/dev/null || source ~/.bashrc  # bash
```

로컬 개발 빌드에서 직접 설치하려면:

```sh
./install.sh
```

xcodegen + xcodebuild로 앱과 binary를 빌드하고 로컬에 설치합니다.

### 제거

기본 제거는 앱, CLI binary, shell wrapper, installer receipt를 지우고 프로젝트 목록과 설정 데이터는 보존합니다.

```sh
sudo /usr/local/bin/goto-uninstall
```

DMG를 다시 열 수 있으면 `Uninstall Goto.command`를 실행해도 됩니다.

사용자 데이터까지 모두 지우려면:

```sh
sudo /usr/local/bin/goto-uninstall --purge
```

`--purge`는 `~/.goto`, `~/.goto_recent`, `~/.goto_pinned`, `~/.goto_config`, Goto preferences, Finder Sync container data까지 제거합니다. 제거 스크립트는 예전 설치 방식의 `/Applications/GotoLauncher.app`, `Goto3` 앱 이름, `~/.local/bin/goto`, old shell marker도 함께 정리합니다.

## 메뉴바 (Settings 토글)

Goto.app Settings에서 **"메뉴바에서 빠르게 열기"** 체크 시 메뉴바에 터미널 아이콘이 추가됩니다.

- 클릭 시 등록된 프로젝트 리스트 (CLI와 동일한 `~/.goto`) 표시
- 핀 고정한 프로젝트가 최상단에 📌 마커와 함께 표시되고, 그 아래에 최근 선택한 프로젝트 3개가 표시됩니다.
- 메뉴 항목에 ⌥(Option) 키를 누른 채 호버하면 "핀 고정"/"핀 해제" alternate 항목이 표시됩니다. 클릭하면 토글됩니다.
- Settings의 **"프로젝트 그룹화"** 체크 시 최근 항목 아래의 프로젝트를 상위 폴더별 submenu로 묶습니다. 체크하지 않으면 프로젝트를 직렬 리스트로 표시합니다.
- 메뉴바 프로젝트 항목은 프로젝트명만 표시하고, 전체 경로는 항목 hover tooltip으로 표시합니다.
- 항목 클릭 → 설정한 기본 터미널로 그 폴더 열기 (Finder의 "Open in Terminal"과 동일 동작)
- `~/.goto` 파일 변경은 `DispatchSourceFileSystemObject`로 실시간 반영 (CLI로 add/remove 시 즉시 갱신)
- 메뉴바 활성화 상태에서는 Settings 윈도우를 닫아도 앱이 백그라운드에 남아 메뉴바를 유지

## Wiki

프로젝트 지식 베이스는 `wiki/`에 llm-wiki 형태로 관리합니다.

- `wiki/SCHEMA.md` — 문서 범위, 태그, 작성 규칙
- `wiki/index.md` — 지식 베이스 목차
- `wiki/log.md` — 변경 로그
- `wiki/concepts/` — 기능과 설계 개념
- `wiki/summaries/` — 변경 요약

## URL Scheme

- `gotolauncher://open?path=…` — Goto Launcher가 받아 터미널을 엽니다.

## 아키텍처 메모

- Finder Sync 확장(`GotoFinderSync.appex`)은 macOS 정책상 sandbox 필수입니다. sandbox는 컨테이너 외부 경로의 파일 read와 외부 바이너리 실행을 차단합니다.
- 확장의 `NSMenuItem`은 Finder 프로세스로 직렬화되며, 보존되는 속성은 `title/action/image/enabled/tag/state/indentationLevel/submenu`로 한정됩니다. `representedObject`/`toolTip`은 보존되지 않으므로 메뉴에서 클릭 핸들러로 데이터를 전달할 때는 `tag` + 로컬 dictionary 패턴을 사용합니다 (`FinderSyncExtension.swift`의 `menuPayloads`).

## 빌드

```sh
xcodegen generate
xcodebuild -project Goto.xcodeproj -scheme Goto -configuration Debug build
```

Release 앱 설치는 `Install Goto.pkg`가 `/Applications`와 `/usr/local/bin`에 필요한 파일을 배치합니다. 프로젝트 루트에는 빌드 산출물 앱 번들을 보관하지 않습니다.

Release 인스톨러 패키지는 빌드 후 다음 명령으로 생성합니다.

```sh
./scripts/build-installer.sh vX.Y.Z
```

## 사용

1. `Install Goto.pkg`를 실행합니다.
2. `Goto.app`을 실행합니다.
3. 기본 터미널을 선택합니다. Ghostty가 설치되어 있으면 선택지에 표시됩니다.
4. 터미널이 이미 실행 중일 때 `New Tab` 또는 `New Window` 중 하나를 선택합니다.
5. Finder에서 `View > Customize Toolbar...`를 엽니다.
6. `Goto` 항목을 도구막대로 끌어다 놓습니다.

한 번 클릭으로 바로 실행하려면 `/Applications/Goto Launcher.app`을 Finder 도구막대로 직접 끌어다 놓습니다.

Installer는 `Goto Finder Extension`을 자동으로 활성화하고 Finder를 새로고침합니다. macOS 설정이 이를 막아 `Goto` 항목이 보이지 않으면 `Goto.app`의 `Open Extension Settings`에서 수동으로 활성화하세요.

macOS가 Terminal, Ghostty 제어 권한이나 Accessibility 권한을 물어보면 허용해야 현재 경로에서 탭을 열 수 있습니다.
