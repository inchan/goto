# Phase 1: Registry And Command Core - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning
**Source:** GSD initialization synthesis

<domain>
## Phase Boundary

Phase 1 establishes the executable contract and the local registry layer that the rest of `goto` will depend on. At the end of this phase, the project should have a runnable local CLI, canonical path handling, durable add/remove commands, and a repo-local install path.

This phase does not include the interactive picker UI or parent-shell `cd` integration. Those belong to Phase 2.

</domain>

<decisions>
## Implementation Decisions

### Runtime
- Use the local Node.js runtime already available in the environment.
- Keep the implementation buildless and in plain ESM JavaScript.

### Registry
- Persist saved projects in `~/.goto`.
- Store one canonical absolute path per line.
- Rewrite atomically to avoid corruption across shells.

### CLI Shape
- Keep one public CLI entrypoint for local execution from the repository.
- Reserve machine-readable stdout for future selection output.
- Human-facing status and errors should not block later shell integration.

### Validation
- Use the built-in Node test runner for fast feedback.
- Validate registry mutations with a temporary `HOME` to avoid touching the real user registry during tests.

</decisions>

<specifics>
## Specific Ideas

- Expected file layout for this phase:
  - `package.json`
  - `bin/goto.js`
  - `src/cli.js`
  - `src/paths.js`
  - `src/registry.js`
  - `src/commands/add.js`
  - `src/commands/remove.js`
  - `test/*.test.js`
- `goto -a` and `goto -r` without an explicit path should operate on the current working directory.
- Duplicate prevention should happen after canonicalization, not by raw string comparison.

</specifics>

<deferred>
## Deferred Ideas

- Interactive picker UI
- `zsh` and `bash` wrapper functions that perform parent-shell `cd`
- Empty-state and visual polish work beyond basic CLI clarity
- Search, tags, aliases, and any metadata beyond raw paths

</deferred>

---

*Phase: 01-registry-and-command-core*
*Context gathered: 2026-03-12 via GSD initialization synthesis*
