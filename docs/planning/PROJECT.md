# goto

## What This Is

`goto` started as a minimal terminal utility for jumping into registered project directories from anywhere. The product now expands that core into a broader macOS launcher: the shell workflow remains the foundation, with a native menu bar surface for the same shared project list.

The primary user is an individual developer optimizing their own local terminal workflow.

## Core Value

From anywhere in macOS, get to the right project directory in one quick, low-friction interaction.

## Requirements

### Validated (v1.0 — completed 2026-03-22)

- [x] User can run `goto` from anywhere and choose a registered project from a keyboard-driven list.
- [x] User can register and remove directories with `goto -a`, `goto -a PATH`, `goto -r`, and `goto -r PATH`.
- [x] Shell integration works in `zsh` and `bash`, with the selected project opening as the active working directory in the parent shell.
- [x] The TUI shows project name and path and supports up/down navigation, Enter to jump, and Esc to exit.
- [x] Project registry persists locally in a simple dotfile-based format.
- [x] A native macOS menu bar surface can show saved projects and open them in Terminal.

## Out of Scope

- Shared team sync of project lists
- Remote storage or cloud backup
- Rich fuzzy search, tags, or project metadata
- Publishing as an npm package

## Context

The user wants a very small amount of code that still feels intentional and polished. The core interaction still starts with a terminal-first picker and a refined presentation, but the product is also expected to offer a native macOS menu bar entry point so the same project list can be reached without first opening a shell.

Because a standalone child process cannot change the caller's current directory, shell integration is part of the actual product, not an implementation detail.

## Constraints

- Local install only for v1
- Minimal code
- `zsh` and `bash` first
- Dotfile storage
- Keyboard-first TUI
- Menu bar app built with native macOS APIs
- Full Xcode required for native builds

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Support `zsh` and `bash` in v1 | The product must change the active shell directory | ✅ Shipped |
| Use a local dotfile registry | Keeps persistence simple | ✅ Shipped |
| Show both project name and path in the picker | Preserves clarity when folder names collide | ✅ Shipped |
| Prioritize local install over package publishing | Keeps v1 focused on proving the workflow | ✅ Shipped |
| Keep `~/.goto` as the single shared registry across shell and native surfaces | Avoids drift between the CLI and menu bar entry points | ✅ Shipped |
| Use a native macOS menu bar host | The menu bar surface is platform-native | ✅ Shipped |

---
*Last updated: 2026-04-01 — Finder integration removed; CLI + menu bar app retained*
