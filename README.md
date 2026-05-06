# Goto

Finder Sync Extension 기반 터미널 열기 앱입니다.

## 설치 (Release)

GitHub Releases에 두 자산이 첨부됩니다.

- `Goto-vX.Y.Z.dmg` — `Goto.app` + `Goto Launcher.app` 인스톨러. 마운트 후 두 앱을 `Applications` 단축에 드래그합니다.
- `goto-cli-vX.Y.Z.zip` — CLI binary + `install-cli.sh`. 압축을 풀고 `./install-cli.sh`를 실행하면 `~/.local/bin/goto`로 설치되고 셸 함수가 등록됩니다.

처음 실행 시 macOS Gatekeeper가 "확인되지 않은 개발자" 경고를 띄울 수 있습니다. 다음 둘 중 하나로 우회하세요.

```sh
# 방법 1: Finder에서 Goto.app 우클릭 → 열기 (한 번만 승인하면 됩니다).
# 방법 2: quarantine 속성 제거.
xattr -dr com.apple.quarantine /Applications/Goto.app "/Applications/Goto Launcher.app"
```

## 동작

- Finder Sync 도구막대의 `Goto` 버튼을 클릭하면 두 항목 메뉴가 열립니다.
  - `Open in Terminal` — 현재 Finder 위치를 설정한 기본 터미널로 엽니다.
  - `Worktrees…` — 현재 위치가 git 저장소면 worktree 선택 윈도우를 띄웁니다.
- Worktree 윈도우에서 행을 더블클릭하거나 Enter를 누르면 해당 worktree 경로를 터미널로 엽니다. ESC로 닫습니다.
- 윈도우는 `Goto.app` 메인 앱이 띄웁니다 (Finder Sync 확장은 sandbox로 git 실행이 막혀 있어 메인 앱에 위임).
- Finder 도구막대에 `Goto Launcher.app`을 직접 끌어다 놓고 클릭하면 메뉴 없이 기본 터미널이 바로 열립니다.
- 설정 화면에서 기본 터미널과 "이미 실행 중일 때 새 탭/창" 동작을 선택합니다. Ghostty가 설치되어 있으면 선택지에 표시됩니다.
- 터미널 앱이 이미 열려 있으면 설정값에 따라 새 탭 또는 새 창으로 엽니다. 열려 있지 않으면 항상 새 창을 엽니다.
- Terminal.app의 새 탭 열기는 macOS Accessibility 권한이 필요합니다. 권한이 없으면 새 창으로 엽니다.
- Finder에서 파일/폴더를 우클릭했을 때도 같은 두 메뉴 항목을 제공합니다.

Finder Sync 도구막대 버튼은 공개 API에서 왼쪽 클릭, 오른쪽 클릭, 롱클릭을 구분하지 않습니다.
Finder Sync는 도구막대 버튼 클릭 시 메뉴만 요청하므로, 진짜 한 번 클릭 실행은 `Goto Launcher.app`을 Finder 도구막대에 직접 추가해서 사용합니다.

## CLI (`goto`)

터미널 어디에서든 사용할 수 있는 인터랙티브 프로젝트 네비게이터입니다.

```sh
goto                              # 등록된 프로젝트 리스트 → ↑↓ 이동, Enter 선택, ESC 취소
goto --add <path>                 # 경로 등록
goto --remove <path>              # 경로 제거
goto --add-subdirs <path>         # 1단계 하위 git 디렉터리 모두 등록
goto --remove-subdirs <path>      # 1단계 하위 디렉터리 모두 제거
goto --help                       # 도움말
```

- 등록 데이터: `~/.goto` (한 줄 한 path, 사용자가 직접 편집 가능)
- 최근 선택한 프로젝트 3개는 `~/.goto_recent`에 저장되고, 인터랙티브 리스트와 메뉴바 리스트의 최상단에 표시됩니다.
- 정렬 설정은 `~/.goto_config`에 저장됩니다. CLI settings에서 상위 폴더 정렬과 프로젝트 정렬을 각각 이름/생성일, 오름차순/내림차순으로 변경할 수 있습니다.
- 인터랙티브 선택은 **현재 셸에서 `cd`**합니다. 셸 함수 wrapper(install 스크립트가 `~/.zshrc`/`~/.bashrc`에 멱등 추가)가 binary stdout을 받아 `cd` 실행
- 비TTY(파이프) 호출 시 리스트를 stdout 한 줄씩 출력 (`goto | grep ...` 가능)

### 설치

```sh
./install.sh
```

xcodegen + xcodebuild로 binary 빌드 → `~/.local/bin/goto` 복사 → `~/.zshrc`/`~/.bashrc`에 셸 함수 추가.

설치 후 `source ~/.zshrc` 또는 새 셸 세션을 여세요.

## 메뉴바 (Settings 토글)

Goto.app Settings에서 **"메뉴바에서 빠르게 열기"** 체크 시 메뉴바에 터미널 아이콘이 추가됩니다.

- 클릭 시 등록된 프로젝트 리스트 (CLI와 동일한 `~/.goto`) 표시
- 최근 선택한 프로젝트 3개가 최상단에 표시됩니다.
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
- `gotoworktree://show?path=…` — Goto 메인 앱이 받아 worktree 선택 윈도우를 띄웁니다.

## 아키텍처 메모

- Finder Sync 확장(`GotoFinderSync.appex`)은 macOS 정책상 sandbox 필수입니다. sandbox는 컨테이너 외부 경로의 파일 read와 외부 바이너리 실행을 차단해, 확장 내부에서 임의 git 저장소의 `git worktree list` 또는 `.git` 직접 read 모두 EPERM이 발생합니다.
- 따라서 worktree 조회는 sandbox가 꺼진 메인 앱(`Goto.app`)이 담당합니다. 확장은 path만 URL scheme으로 메인 앱에 던지고, 메인 앱이 git을 실행해 윈도우에 결과를 표시합니다.
- 확장의 `NSMenuItem`은 Finder 프로세스로 직렬화되며, 보존되는 속성은 `title/action/image/enabled/tag/state/indentationLevel/submenu`로 한정됩니다. `representedObject`/`toolTip`은 보존되지 않으므로 메뉴에서 클릭 핸들러로 데이터를 전달할 때는 `tag` + 로컬 dictionary 패턴을 사용합니다 (`FinderSyncExtension.swift`의 `menuPayloads`).

## 빌드

```sh
xcodegen generate
xcodebuild -project Goto.xcodeproj -scheme Goto -configuration Debug build
```

Release 앱 설치는 빌드 산출물의 `Goto.app`과 `GotoLauncher.app`을 `/Applications`로 복사해서 진행합니다. 프로젝트 루트에는 빌드 산출물 앱 번들을 보관하지 않습니다.

## 사용

1. `Goto.app`을 `/Applications` 또는 `~/Applications`로 옮깁니다.
2. `Goto.app`을 실행합니다.
3. 기본 터미널을 선택합니다. Ghostty가 설치되어 있으면 선택지에 표시됩니다.
4. 터미널이 이미 실행 중일 때 `New Tab` 또는 `New Window` 중 하나를 선택합니다.
5. `Open Extension Settings`를 누르고 `Goto Finder Extension`을 활성화합니다.
6. Finder에서 `View > Customize Toolbar...`를 엽니다.
7. `Goto` 항목을 도구막대로 끌어다 놓습니다.

한 번 클릭으로 바로 실행하려면 `/Applications/Goto Launcher.app`을 Finder 도구막대로 직접 끌어다 놓습니다.

macOS가 Terminal, Ghostty 제어 권한이나 Accessibility 권한을 물어보면 허용해야 현재 경로에서 탭을 열 수 있습니다.
