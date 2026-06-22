# Goto Wiki Log

## 2026-06-22 feat | CLI 자동 업데이트 (알림 + self-update)

`GotoUpdateService`를 추가해 GitHub Releases `latest`의 tag를 비교한다. 인터랙티브 진입 시 기존 백그라운드 `goto --sync` 프로세스가 24h TTL로 `~/.goto_update_check` 캐시를 갱신하고, 메인 리스트는 캐시를 읽어 새 버전이면 상단에 `⬆ 새 버전 … — goto --upgrade` 한 줄을 표시한다(반영은 다음 실행). `goto --upgrade`는 최신 DMG를 받아 `hdiutil`로 마운트하고 `sudo installer`로 `Install Goto.pkg`를 전체 설치한다. dev 빌드(0.0.0)는 체크를 건너뛴다. 버전은 빌드 시 주입된 `CFBundleShortVersionString`을 사용. See `docs/superpowers/specs/2026-06-22-cli-auto-update-design.md`.

## 2026-06-22 refactor | worktree 기능 제거

Finder Sync "Worktrees…" 메뉴와 worktree 선택 윈도우, `gotoworktree://` URL scheme을 모두 제거했다. `Shared/WorktreeService.swift`, `GotoApp/WorktreeWindow.swift`, `GotoTests/WorktreeServiceTests.swift`를 삭제하고 `GotoLaunchRequest`에서 worktree scheme/action/url을, `FinderSyncExtension`에서 메뉴 항목·tag·핸들러를, `AppDelegate`에서 URL 핸들러(worktree 제거로 dead가 된 `application(_:open:)`/`handleURL` 포함)를, `Info.plist`/`project.yml`에서 URL scheme 등록을 제거했다. Finder Sync 메뉴는 `Open in Terminal` 단일 항목으로 단순화됐고, 남은 git 실행 코드는 프로젝트 등록용 `GotoProjectStore.isGitManagedDirectory`뿐이다.

## 2026-06-22 feat | watched-subdirs 자동 동기화 + CLI 단축 플래그

`--add-subdirs`로 등록한 상위 폴더를 `~/.goto_watched`에 감시 대상으로 기억하고, 인터랙티브 모드 진입 시 백그라운드(`goto --sync` detached 프로세스)로 하위 git 프로젝트를 재동기화한다. 추가 기준은 직속 하위 git 루트, 제거 기준은 폴더가 물리적으로 삭제된 경우다. 수동 실행용 `--sync`/`-S`, 감시 해제용 `--unwatch`/`-U`를 추가했고 모든 CLI 명령에 단축 플래그(`-a/-r/-A/-R/-p/-u/-U/-S/-h`)를 부여했다. watched parent가 디렉터리로 사라지면 하위 등록과 watch 항목을 함께 정리하며, 외장/네트워크 볼륨 언마운트도 동일 경로로 처리됨에 유의(로컬 폴더 사용 권장).

## 2026-06-17 fix | Finder Sync 자동 활성화

Installer postinstall과 로컬 `install.sh`가 설치 직후 `com.inchan.goto.findersync`를 `pluginkit -e use`로 활성화하고 Finder를 새로고침하도록 변경했다. 기존 uninstall이 확장을 `ignore`로 둔 뒤 재설치해도 Finder 도구막대 사용자화에 `Goto`가 나타나도록 하기 위함이다. Finder toolbar item이 64pt glyph canvas를 기준으로 넓게 잡히는 문제를 줄이기 위해 `goto-glyph.pdf` media box를 18pt로 낮추고 Finder Sync에서 18x18 template image로 반환한다. See `summaries/installer-pkg-2026-06-16`.

## 2026-06-16 feat | pkg 기반 일괄 설치

Release DMG의 설치 단위를 두 앱 드래그 방식에서 `Install Goto.pkg` 하나로 바꿨다. pkg payload는 `/Applications/Goto.app`, `/Applications/Goto Launcher.app`, `/usr/local/bin/goto`, `/usr/local/bin/goto-uninstall`을 함께 설치하며, postinstall에서 현재 콘솔 사용자의 zsh/bash 시작 파일에 marker 기반 `goto()` wrapper를 등록한다. 별도 `goto-cli-vX.Y.Z.zip` 릴리스 자산은 제거했다. 제거 스크립트는 현재 설치물과 legacy 앱 이름, old shell marker, 예전 `~/.local/bin/goto`까지 정리하고 `--purge` 시 사용자 데이터도 제거한다. See `summaries/installer-pkg-2026-06-16`.

## 2026-05-19 refine | CLI 키 정책 + 스킬 리네이밍

CLI 인터랙티브 리스트의 단축키 정책을 **"입력 시 자동 필터"** 로 단순화했다. 단일 알파벳 단축키(`f`/`p`/`q`)를 모두 제거하고, 사용자가 임의의 printable 글자를 누르면 즉시 필터 모드로 진입하면서 그 글자가 첫 쿼리 문자로 주입된다. 핀 토글은 `Ctrl+P` (0x10), 종료는 `Ctrl+Q` (0x11) 로 옮겼으며 `ESC` / `Ctrl+C` 종료는 유지된다. macOS 터미널 raw 모드가 `Cmd+키`를 키스트로크로 전달하지 않기 때문에 `Ctrl+` 채택. `Key` enum 에 `.printable(UInt8)` associated value 케이스를 추가하면서 settings 화면의 `key == .enter` 비교를 `if case .enter = key` 패턴으로 교체했다. 같은 사이클에 출하 파이프라인 스킬 `ship-goto` 를 `deploy` 로 리네이밍 (`/deploy`, 부분 실행은 `/deploy {cleanup,docs,build,publish}`; Stage 0에서 자동/수동 모드 1회 선택). 중간 단계로 `release` 이름을 거쳤으나 `.github/workflows/release.yml` CI 명과 혼동 우려로 최종 `deploy` 채택. README CLI 사용법 한 줄과 핀 설명을 새 정책에 맞춰 갱신. See `summaries/cli-keybindings-2026-05-19`.

## 2026-05-13 refine | CLI prefix palette + cleanup menu

사용자 피드백을 반영해 prefix 배경색 알고리즘을 두 차례 다듬었다. (1) 초기 FNV-1a → HSL 무한 hue 매핑이 녹색 편중·탁한 인상을 줘서, (2) 16색 어두운 톤 큐레이트 → vivid Tailwind 600 → 최종 **8색 큐레이트** 로 정착했다. 8색은 hue family 당 1개씩만 두고, **linear-probed 슬롯 할당** 으로 현재 표시 중인 unique prefix 끼리 색이 겹치지 않도록 보장한다. 배경 휘도 기준으로 검은/흰 글자를 자동 선택해 옅은 색에서도 가독성을 유지한다. 같은 사이클에 프로젝트 관리 화면에 `정리 (N)` 메뉴를 추가했다. N 은 등록된 경로 중 디렉토리가 존재하지 않는 항목 수이며, Enter 시 일괄 제거된다. See `summaries/cli-prefix-features-2026-05-13`.

## 2026-05-13 feat | CLI prefix color, f filter, pattern prefix

CLI 인터랙티브 모드에 prefix true-color 배경 배지(FNV-1a 64-bit → HSL with sat/light variants), `f` 키 필터(Claude Code 스타일), 동일 prefix 가 2개 이상 등록됐을 때만 적용되는 `xxx-` 패턴 prefix 매칭을 추가했다. 설정에 `prefixColorEnabled`, `prefixPatternEnabled` 두 토글을 노출해 영속 저장한다. 패턴 prefix 활성화 시 정렬 키도 패턴 prefix 로 통일되어 동일 prefix 항목이 인접 배치된다. 메뉴바 앱 동작은 변하지 않는다. See `summaries/cli-prefix-features-2026-05-13`.

## 2026-05-06 init | project wiki

Initialized the llm-wiki structure for durable Goto project knowledge.

## 2026-05-06 cleanup | shared project list behavior

Recorded the cleanup pass that moved CLI project list behavior onto the shared implementation and documented menu bar grouping behavior.

## 2026-05-06 refactor | deterministic project list model

Centralized sort option identifiers, next-option transitions, and ordered project output in the shared project-list model. Documented the refactor boundary in `concepts/shared-project-list-model`.

## 2026-05-06 refactor | simple output boundary

Removed the shared row enum and kept separator rows inside the CLI. Simplified CLI project layout to column widths only, while preserving ordered project output from the shared model.

## 2026-05-06 review | Claude simplicity pass

Ran an external Claude review over the uncommitted diff. Applied the clear fixes: menu bar groups now key by full parent path, settings navigation dropped a redundant always-selectable abstraction, and root app bundles are ignored.

## 2026-05-06 rename | Goto product name

Renamed the product from Goto3 to Goto across app targets, CLI target, bundle identifiers, URL schemes, Swift types, tests, docs, and install flow. The CLI data files remain `~/.goto`, `~/.goto_recent`, and `~/.goto_config` because they were already the canonical user data paths.

## 2026-05-11 fix | menu bar & Finder Sync glyph

Fixed the white square that appeared in the menu bar and Finder Sync toolbar after the P03 icon swap. The mono PDF branch of `scripts/generate-icons.swift` was calling `ctx.clear(rect)`, which on `CGPDFContext` emits a full-page black fill instead of clearing alpha. Removed the call and also wired `iconutil` into the script so `.icns` stays in sync with the iconset PNGs. See `summaries/icon-glyph-fix-2026-05-11`.

## 2026-05-11 fix | settings window front-most

Fixed the menu bar "Settings…" action so the configuration window reliably comes to the front on macOS 14+. Added a `bringToFront(_:)` helper that re-asserts `.regular` activation policy, uses the modern `NSApp.activate()` on macOS 14+, and calls `orderFrontRegardless()`. Hooked `NSWindowDelegate.windowWillClose` so the cached reference is dropped after the user closes the window. See `summaries/settings-window-front-2026-05-11`.

## 2026-05-11 feat | pin feature

Added project pinning. Pinned projects sit above recents in both the CLI interactive list and the menu bar, with a 📌 marker. Data lives in `~/.goto_pinned` (insertion-ordered) and the CLI/menubar share the same loader. Sorting modes (insertion / name / createdAt × asc/desc) live in `GotoCLIConfig.pinSortMode` and can be changed via CLI Settings or the app Settings popup. CLI toggles: `--pin/--unpin` flags, plus `p` key in the interactive list and the project management screen. Menu bar uses `NSMenuItem.isAlternate = true` with the `.option` modifier so the toggle item appears when ⌥ is held. See `concepts/pin-feature`.
