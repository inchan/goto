# goto

## What This Is

`goto` is a minimal terminal utility for jumping into registered project directories from anywhere. It provides a small TUI that lists saved projects, lets the user move with the arrow keys, press Enter to jump, and press Esc to exit, while also supporting lightweight add/remove commands for path registration.

The primary user is an individual developer optimizing their own local terminal workflow. The product should feel polished and pleasant despite being intentionally small, with UI styling inspired by the clean terminal presentation used by `skills.sh`.

## Core Value

From any shell, get to the right project directory in one quick, low-friction interaction.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can run `goto` from anywhere and choose a registered project from a keyboard-driven list.
- [ ] User can register and remove directories with `goto -a`, `goto -a PATH`, `goto -r`, and `goto -r PATH`.
- [ ] Shell integration works in `zsh` and `bash`, with the selected project opening as the active working directory in the parent shell.
- [ ] The TUI shows project name and path and supports up/down navigation, Enter to jump, and Esc to exit.
- [ ] Project registry persists locally in a simple dotfile-based format.

### Out of Scope

- Shared team sync of project lists — v1 is for a single developer's local machine.
- Remote storage or cloud backup — local persistence is sufficient for the first release.
- Rich fuzzy search, tags, or project metadata — keep the first version minimal.
- Publishing as an npm package — first target is local installation from this repository.

## Context

The user wants a very small amount of code that still feels intentional and polished. The core interaction is a terminal-first picker with minimal key handling and a refined presentation rather than a feature-heavy launcher.

Because a standalone child process cannot change the caller's current directory, shell integration is part of the actual product, not an implementation detail. That means the design needs a CLI/TUI component plus a thin `zsh`/`bash` wrapper for `cd` behavior.

The expected visual reference is the terminal UI feel of `skills.sh` installation flows: clean spacing, clear hierarchy, restrained ornamentation, and better-than-default terminal aesthetics without turning the tool into a framework-heavy app.

## Constraints

- **Scope**: Local install only — v1 should work from this repository without package publishing overhead.
- **Implementation**: Minimal code — prefer a small architecture with as little moving parts as possible.
- **Shells**: `zsh` and `bash` first — these are the required initial integration targets.
- **Persistence**: Dotfile storage — registry should live in a simple user-level dotfile.
- **Interaction**: Keyboard-first TUI — up/down, Enter, and Esc are required behaviors.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Support `zsh` and `bash` in v1 | The product must change the active shell directory, so shell integration cannot be deferred | — Pending |
| Use a local dotfile registry | Keeps persistence simple and aligned with the user's preference | — Pending |
| Show both project name and path in the picker | Preserves clarity when folder names collide or are ambiguous | — Pending |
| Prioritize local install over package publishing | Keeps v1 focused on proving the workflow with minimal code | — Pending |
| Style the TUI after `skills.sh` terminal presentation | UI quality matters even though the tool itself is intentionally small | — Pending |

---
*Last updated: 2026-03-12 after initialization*
