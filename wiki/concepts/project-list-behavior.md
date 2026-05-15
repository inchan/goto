---
title: "Project List Behavior"
date: 2026-05-06
tags: [cli, menubar, settings]
---

# Project List Behavior

Goto stores registered projects in `~/.goto`, one absolute path per line. `GotoProjectStore` owns normalization, add/remove behavior, and one-level subdirectory registration. `--add-subdirs` only adds direct child directories that are git repository roots.

Project display behavior is centralized in `GotoProjectList` in `Shared/GotoCLISettings.swift`. Both the CLI and menu bar use this shared model for recents, sorting, display names, and home path shortening. This avoids the CLI and app drifting apart.

Recent projects are stored in `~/.goto_recent`. The most recently selected valid project appears first. The displayed count is user-configurable via `GotoCLIConfig.recentLimit` (CLI settings → `최근 항목 개수`, or the macOS app settings window → `최근 개수`). Allowed values are `0, 1, 3, 5, 10`; the default is `5`. A value of `0` disables the recents block entirely. The file itself stores up to `max(recentLimit, defaultRecentLimit)` entries so that raising the limit recovers previous history. Recents are filtered against the current project store, so deleted or unregistered paths do not appear.

Sorting is controlled by `GotoCLIConfig`. The parent folder and project name each have an independent sort field and direction. Supported fields are name and creation date. Supported directions are ascending and descending. The default is name descending for both parent and project sorting.

In the CLI, the main list renders recent projects first, then a separator, then the remaining sorted projects, then settings. Project rows show parent folder, bold project name, and a gray shortened path.

In the menu bar, recent projects always appear at the top. The `프로젝트 그룹화` setting controls only the remaining projects. When grouping is off, remaining projects appear as a direct list. When grouping is on, remaining projects are grouped under parent folder submenu items. The group key is the full parent path, while the submenu title remains the parent folder name. This prevents unrelated folders with the same name from merging. Project menu items show only the project name; the full path is available as the AppKit tooltip.

Related pages: [[concepts/settings-persistence]].
