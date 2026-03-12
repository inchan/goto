# Stack Recommendation

Date: 2026-03-12

## Recommendation

Build `goto` as a buildless Node.js CLI with one prompt dependency and a thin sourced shell wrapper.

- Runtime: Node.js 24 LTS, plain ESM JavaScript.
- Prompt/TUI: current stable `@clack/prompts` release.
- Core APIs: `node:util.parseArgs`, `node:fs/promises`, `node:path`, `node:os`, `node:process`.
- Install: `npm install` then `npm link` from this repo.
- Shell integration: one `goto` function for `zsh`, one for `bash`.
- Registry: `~/.goto` as a newline-delimited list of normalized absolute paths.

This is the smallest stack that still gives a polished selector, low install friction, and a clean shell-integration story.

## Why This Stack

- Node 24 is the current Active LTS as of 2026-03-12, so it is the boring, supported target for a new local utility.
- This tool is not a platform. It needs file I/O, argument parsing, and one interactive list. Node already covers almost all of that in core.
- Clack gives a cleaner terminal presentation than default prompt libraries without forcing a full TUI framework.
- `npm link` is the simplest local-install path because it exposes the package `bin` globally from the working tree and fits the repo-local workflow.

## Recommended Shape

1. Keep the executable logic in one small Node entrypoint.
2. Keep shell integration in two tiny sourced files: one for `zsh`, one for `bash`.
3. Reserve `stdout` for machine-readable path output in selection mode.
4. Render the interactive UI to `stderr` via Clack's custom output stream support.
5. On successful selection, print exactly one absolute path plus newline to `stdout` and exit `0`.
6. On `Esc`/cancel, print nothing and exit `1`.
7. For `-a` and `-r`, mutate the registry and print human-facing status only; do not emit a path.

That contract is what makes parent-shell `cd` work reliably:

- The shell function runs `command goto ...` to bypass itself.
- The shell function captures `stdout` into a variable.
- If a path comes back, the shell function runs `cd "$path"` in the parent shell.

## Libraries And Tooling

Use:

- `@clack/prompts` for the picker UI and minimal intro/cancel/outro styling.
- Node built-ins for everything else.
- `npm` as the package manager for v1, because it is already present with Node and pairs directly with `npm link`.

Do not add for v1:

- `commander`, `cac`, `yargs`
  `parseArgs` is enough for `-a`, `-r`, optional path input, and help text.
- `chalk`, `kleur`, extra color wrappers
  Clack already owns the prompt styling; adding another color layer increases drift.
- config libraries like `conf` or `cosmiconfig`
  A single dotfile does not need a config abstraction.
- a TypeScript build chain
  For this size of tool, plain JS is less code and removes compile/install steps.

## Storage Recommendation

Use `~/.goto` with one absolute path per line.

- Normalize on write with `realpath`-style resolution where practical.
- Deduplicate and sort on every write.
- Do not store `~`, relative paths, or shell-specific expansions.
- Derive the display name from `basename(path)` and always show the full path as secondary text.

This is simpler than JSON, easy to inspect manually, and sufficient for v1. If aliases or metadata become necessary later, migrate then.

## What Not To Use

- Ink / React
  Too much framework and render-model overhead for a one-screen selector.
- Blessed or other ncurses-style full TUI stacks
  They solve a much bigger problem than this app has.
- `fzf` as a required dependency
  It adds an external install requirement and gives up too much control over the branded UI feel.
- Pure shell for the full app
  The shell wrapper is necessary, but building the selector itself in bash/zsh makes raw key handling, rendering, and polish harder than it should be.
- Go or Rust for v1
  Good for single-binary distribution, but worse for a repo-local utility where minimal code and iteration speed matter more than packaging.

## Defaults To Lock In

- `package.json` with `"type": "module"` and a `bin` entry for `goto`
- `engines.node` set to `>=24`
- No global state beyond `~/.goto`
- No fuzzy search, no tags, no metadata in v1
- No package publishing work in v1

## Decision

Use Node 24 + `@clack/prompts` + two sourced shell wrappers. Avoid a compiled binary, avoid a full TUI framework, and avoid unnecessary dependencies.
