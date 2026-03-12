# Features Research: `goto`

## Product Frame

`goto` is a minimal local-install terminal utility for one developer on one machine. The product is not just a CLI binary; it is a small executable plus shell integration that lets a picker result change the parent shell's working directory in `zsh` and `bash`.

For v1, the strongest feature strategy is:

- ship the smallest possible "project jumper" that feels intentional
- invest in flow polish, not feature breadth
- avoid anything that adds state, indexing, search, or multi-user concerns

## Table Stakes

These are the features that make the tool viable at all.

| Feature | Why it matters | Complexity | Dependencies / Notes |
| --- | --- | --- | --- |
| Shell integration for `zsh` and `bash` | Core product requirement. Without this, the tool can only print a path, not actually jump the parent shell. | Medium | Requires a sourced shell function or wrapper that calls the executable, captures the selected path, and runs `cd` in the caller shell. |
| TUI picker with up/down, Enter, Esc | Main interaction model. Must be reliable and immediate. | Medium | Needs terminal raw-mode input handling and simple screen rendering, either via stdlib terminal control or one small TUI dependency. |
| Local registry in a user dotfile | Persistence is essential and should stay human-inspectable. | Low | Depends only on filesystem access and home directory resolution. JSON, newline-delimited paths, or another trivial format all fit v1. |
| `goto -a`, `goto -a PATH`, `goto -r`, `goto -r PATH` | Required management surface for adding and removing projects without editing the dotfile manually. | Low | Needs path normalization, current-directory detection, and clear error messages for invalid paths. |
| Show both project name and full path | Prevents ambiguity when multiple folders share the same basename. | Low | Pure presentation concern, but important for trust and fast selection. |
| Safe cancel behavior | `Esc` should exit cleanly and never change directory. | Low | Must have a clear no-op result channel back to the shell wrapper. |
| Duplicate and missing-path handling | Prevents the registry from degrading quickly in real use. | Low to Medium | At minimum: avoid duplicate registrations and handle deleted directories gracefully in the picker or remove flow. |

## Differentiators

These are the features most likely to make `goto` feel polished without turning it into a bigger product.

| Feature | User impact | Complexity | Dependencies / Notes |
| --- | --- | --- | --- |
| Clean visual hierarchy in the picker | Makes the TUI feel deliberate instead of generic. Project name can be prominent while the path is quieter. | Low | Mostly styling and layout decisions; no major technical cost. |
| Tight empty-state and install guidance | Makes first-run experience understandable without docs. | Low | Helpful when the registry is empty or shell integration is not sourced yet. |
| Canonical path storage | Reduces subtle bugs from `.`/`..`, symlinks, or relative-path duplicates. | Low | Depends on path resolution helpers available in the chosen runtime. |
| Stable ordering of projects | Improves predictability and muscle memory. | Low | Alphabetical ordering is simplest; "most recently used" is possible but adds state and should be optional. |
| Clear, restrained CLI copy | Reinforces the "small but polished" feel in add/remove confirmations and errors. | Low | No extra dependency; just disciplined output design. |

## Anti-Features

These should stay out of v1 because they add more product surface than they add value.

| Anti-feature | Why to exclude it | Complexity impact |
| --- | --- | --- |
| Fuzzy search or live filtering | Attractive, but it adds input-state complexity and changes the interaction model from a tiny picker to a search app. | Medium |
| Tags, groups, favorites, or metadata | Useful only after the registry is much larger. Premature for a minimal single-user tool. | Medium |
| Team sync, cloud backup, or shared registries | Conflicts with the local-first scope and creates auth/storage concerns unrelated to the core jump workflow. | High |
| Multi-shell support beyond `zsh` and `bash` | Expands testing and shell-specific edge cases before the core product is proven. | Medium |
| Package publishing and installer automation | Useful later, but not necessary for validating the tool from this repository. | Medium |
| Rich project discovery or auto-indexing | Risks turning `goto` into a workspace crawler instead of a deliberate saved-project launcher. | Medium to High |
| Preview panes, icons, mouse support, or heavy UI decoration | Adds code and terminal compatibility risk without materially improving the jump workflow. | Low to Medium |

## Complexity and Dependency View

The main complexity is not the picker itself. It is the shell boundary:

- the executable must communicate a selected path back to a sourced shell function
- the wrapper must work in both `zsh` and `bash`
- cancel and error cases must never accidentally `cd`

Everything else should stay intentionally boring:

- filesystem-only persistence
- no network
- no background processes
- no database
- ideally zero or one small terminal UI dependency

If the chosen runtime can handle raw keyboard input and terminal redraws cleanly with standard libraries, that is the best fit for the project brief. If not, one small, stable TUI dependency is justified, but a framework-heavy stack is not.

## Recommended v1 Cut Line

Ship in v1:

- shell integration for `zsh` and `bash`
- dotfile-backed project registry
- add/remove commands for current directory and explicit path
- picker with up/down, Enter, Esc
- project name plus full path display
- duplicate prevention and graceful handling of missing directories
- polished but restrained terminal presentation

Fast-follow only if the core flow feels solid:

- alphabetical sort refinements
- better empty-state copy
- optional stale-entry cleanup affordances

Do not start in v1:

- fuzzy search
- favorites/tags/recents
- shell support beyond `zsh` and `bash`
- cloud sync or package distribution work
