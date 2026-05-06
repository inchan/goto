---
title: "Shared Project List Model"
date: 2026-05-06
tags: [architecture, cli, menubar, refactor]
---

# Shared Project List Model

Goto keeps deterministic project-list behavior in `Shared/GotoCLISettings.swift`. The shared model owns sort config, sort option identifiers, recent project ordering, display names, and shortened home paths.

The key rule is that the same project input plus the same `GotoCLIConfig` should produce the same ordered output in both CLI and app surfaces. `GotoProjectList.orderedProjects` returns the full display order and the recent boundary. The CLI uses that to insert its separator row. The menu bar uses the same boundary, then either shows the remaining paths directly or groups them by parent folder when `프로젝트 그룹화` is enabled.

`GotoSortOption` owns its stable identifier and next-option transition. UI code should not rebuild identifiers by hand. The App settings popup stores `option.identifier` as the represented object. The CLI settings screen advances via `current.next`.

The CLI still owns terminal-specific rendering details: raw mode, ANSI colors, selected-row inversion, and project column alignment. Those are not shared because AppKit menu rendering has different constraints.

Cleanup decisions from this refactor:

- Removed CLI-local copies of config loading, recent loading, sort comparison, display item, and display path logic.
- Removed the shared project-list row enum because only the CLI needs rows with separators; shared code now returns ordered paths plus the recent boundary.
- Kept CLI column measurement local and simple because it is a terminal rendering concern, not project-list business logic.
- Removed the no-op project-store directory hook.
- Removed the unused main-app entitlement file because `project.yml` does not attach it to the Goto target.

Related pages: [[concepts/project-list-behavior]], [[concepts/settings-persistence]].
