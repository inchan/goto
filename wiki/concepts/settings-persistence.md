---
title: "Settings Persistence"
date: 2026-05-06
tags: [settings, cli, menubar]
---

# Settings Persistence

Goto uses a small number of local preference files and user defaults keys.

Project registration lives in `~/.goto`. It is intentionally plain text so users can inspect and edit it directly. Recent project state lives in `~/.goto_recent`; the displayed cap is `GotoCLIConfig.recentLimit` (default `5`, options `0/1/3/5/10`) and the stored cap is `max(recentLimit, defaultRecentLimit)` so that lowering and raising the limit does not lose history. CLI sorting state lives in `~/.goto_config` as JSON encoded `GotoCLIConfig`.

Menu bar enablement is stored in standard `UserDefaults` with `Goto.menuBarEnabled`. Menu bar project grouping is stored with `Goto.menuBarProjectGroupingEnabled`. The grouping default is false because `UserDefaults.bool(forKey:)` returns false for unset keys.

Terminal preferences are mirrored into the Finder Sync extension preferences file because the extension and app run in different contexts. `GotoSettings` reads the shared preference file first and falls back to standard user defaults. This is why terminal preference code stays separate from the CLI project list settings.

Tests can override store, config, and recent URLs through unsafe static override hooks. These hooks keep XCTest isolated from the user's real `~/.goto`, `~/.goto_config`, and `~/.goto_recent`.

Related pages: [[concepts/project-list-behavior]].
