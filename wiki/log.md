# Goto Wiki Log

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
