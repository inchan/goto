# Goto Wiki Log

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
