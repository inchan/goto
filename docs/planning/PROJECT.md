# goto

## What This Is

`goto` started as a minimal terminal utility for jumping into registered project directories from anywhere. The product now expands that core into a broader macOS launcher: the shell workflow remains the foundation, and future phases add a native menu bar surface plus a Finder-triggered project handoff into Terminal.

The primary user is an individual developer optimizing their own local terminal workflow. The product should feel polished and pleasant despite being intentionally small, with UI styling inspired by the clean terminal presentation used by `skills.sh`.

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
- [x] A Finder-triggered action can open Terminal directly at the selected project folder.

### Out of Scope

- Shared team sync of project lists — v1 is for a single developer's local machine.
- Remote storage or cloud backup — local persistence is sufficient for the first release.
- Rich fuzzy search, tags, or project metadata — keep the first version minimal.
- Publishing as an npm package — first target is local installation from this repository.

## Context

The user wants a very small amount of code that still feels intentional and polished. The core interaction still starts with a terminal-first picker and a refined presentation, but the product is now expected to branch into native macOS entry points so the same project list can be reached without first opening a shell.

Because a standalone child process cannot change the caller's current directory, shell integration is part of the actual product, not an implementation detail. That means the design needs a CLI/TUI component plus a thin `zsh`/`bash` wrapper for `cd` behavior.

Menu bar and Finder integration are different in kind from the existing Node CLI. They require a native macOS host, platform permissions for Terminal automation, and a clear shared contract so the registry and launch semantics do not fork between the shell and native surfaces.

The expected visual reference is the terminal UI feel of `skills.sh` installation flows: clean spacing, clear hierarchy, restrained ornamentation, and better-than-default terminal aesthetics without turning the tool into a framework-heavy app.

## Constraints

- **Scope**: Local install only — v1 should work from this repository without package publishing overhead.
- **Implementation**: Minimal code — prefer a small architecture with as little moving parts as possible.
- **Shells**: `zsh` and `bash` first — these are the required initial integration targets.
- **Persistence**: Dotfile storage — registry should live in a simple user-level dotfile.
- **Interaction**: Keyboard-first TUI — up/down, Enter, and Esc are required behaviors.
- **Platform**: Native macOS surfaces should use first-party platform capabilities instead of trying to fake Finder or menu bar behavior from Node alone.
- **Tooling**: Shipping menu bar and Finder targets will require full Xcode.app, not just Command Line Tools.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Support `zsh` and `bash` in v1 | The product must change the active shell directory, so shell integration cannot be deferred | ✅ Shipped |
| Use a local dotfile registry | Keeps persistence simple and aligned with the user's preference | ✅ Shipped |
| Show both project name and path in the picker | Preserves clarity when folder names collide or are ambiguous | ✅ Shipped |
| Prioritize local install over package publishing | Keeps v1 focused on proving the workflow with minimal code | ✅ Shipped |
| Style the TUI after `skills.sh` terminal presentation | UI quality matters even though the tool itself is intentionally small | ✅ Shipped |
| Keep `~/.goto` as the single shared registry across shell and native surfaces | Avoids drift between the CLI, menu bar, and Finder entry points | ✅ Shipped |
| Use a native macOS host for menu bar and Finder surfaces | These capabilities are platform-native and should not depend on brittle terminal-only hacks | ✅ Shipped |
| Consolidate native surfaces into a single `Goto.app` host | One app now owns the menu bar UI, settings, and Finder bridge lifecycle | ✅ Shipped |
| Keep runtime surfaces and reusable core logically separate in future repo cleanup (`apps/*`, `packages/*`) | Clarifies ownership and makes future restructuring safer without changing behavior first | 🟡 Planned |

---
*Last updated: 2026-03-27 — v1.0 complete, unified `Goto.app` host shipped, repo cleanup planning active*
