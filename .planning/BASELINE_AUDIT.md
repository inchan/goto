# Baseline Audit: Existing Implementation vs Roadmap

**Date:** 2026-03-15
**Status:** Complete

## Objective

Determine how much of Phases 1 through 3 is already present in the codebase before starting native macOS work.

## Summary

The codebase is materially ahead of the recorded execution state in `.planning/STATE.md`.

- `node --test` passes with 24 passing tests.
- Phase 1 appears implemented and covered by automated tests.
- Phase 2 appears implemented and covered by automated tests, including shell-wrapper behavior.
- Phase 3 appears implemented and now has explicit fresh-shell validation in both `zsh` and `bash`, plus a TTY `Ctrl+C` cleanup check.

## Phase Assessment

### Phase 1: Registry And Command Core

Assessment: Functionally implemented

Evidence:
- `package.json` exposes the `goto` bin entrypoint.
- `bin/goto.js` and `src/cli.js` provide the CLI contract.
- `src/registry.js` and `src/paths.js` implement canonical path handling, persistence, and mutation behavior.
- `test/cli-contract.test.js`, `test/command-mutations.test.js`, and `test/registry.test.js` cover help/version, add/remove, duplicate prevention, invalid paths, and registry ordering.

### Phase 2: Picker And Jump Flow

Assessment: Functionally implemented

Evidence:
- `src/select.js` implements the interactive picker, missing-path handling, Enter selection, and Esc cancel behavior.
- `shell/goto.zsh` and `shell/goto.bash` implement parent-shell `cd`.
- `test/install-smoke.test.js` covers wrapper pass-through, successful jump behavior, and cancel behavior.

### Phase 3: Install And Polish

Assessment: Functionally implemented

Evidence:
- `scripts/install-shell.sh` installs shell sourcing blocks for `zsh` and `bash`.
- `README.md` documents setup and raw CLI usage.
- `src/select.js` includes a styled alt-screen picker and empty/missing-path states.
- Fresh-shell validation succeeded in a clean `zsh` session after running `scripts/install-shell.sh --shell zsh`.
- Fresh-shell validation succeeded in a clean `bash` session after running `scripts/install-shell.sh --shell bash`.
- A TTY smoke check confirmed the picker exits cleanly on `Ctrl+C` and restores the terminal screen state.

## Recommendation

1. Do not treat the current roadmap state as literal implementation truth.
2. Reconcile Phase 1 through Phase 3 as code-complete once explicit phase summaries are written.
3. Use the next planning slice to prepare Phase 4 execution artifacts while waiting on Xcode.
4. Start Phase 4 native work only after full Xcode.app is installed and selected.

## Blocking User Action

- Install Xcode.app and switch the active developer directory before native macOS execution starts.

---

*Audit completed: 2026-03-15*
