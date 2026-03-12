# Phase 1 Research: Registry And Command Core

**Date:** 2026-03-12
**Status:** Complete

## Objective

Answer: what do we need to know to plan the registry and command-core phase well?

## Key Findings

### 1. Registry format should stay line-oriented

For v1, a newline-delimited file at `~/.goto` is the best fit.

- It keeps manual inspection and repair trivial.
- It avoids unnecessary schema decisions before aliases or metadata exist.
- It supports duplicate checks after path canonicalization.

### 2. Canonicalize on write, not just on read

`add` and `remove` should normalize paths before comparison.

- Expand relative paths from the current working directory.
- Resolve to absolute paths.
- Normalize separators and trailing slashes.
- Reject missing directories with a clear message instead of storing them.

### 3. Atomic writes matter even for a single-user dotfile

Multiple terminal sessions can mutate the registry close together. Use temp-file plus rename semantics so interrupted writes do not leave a partially written registry behind.

### 4. Command contract should anticipate Phase 2

Even though Phase 1 does not ship the picker, the CLI contract should already avoid a dead end.

- Success paths should return deterministic exit codes.
- Human-facing status copy should be easy to separate from future machine-readable output.
- `--help` and error paths should be explicit so shell wrappers can remain thin later.

### 5. Verification should isolate the user's real HOME

Tests and smoke checks should override `HOME` to a temp directory.

- This keeps automated checks safe.
- It makes duplicate/add/remove cases reproducible.
- It allows install-smoke verification without mutating the developer's real registry.

## Validation Architecture

### Test Stack

- Framework: built-in `node:test`
- Assertion style: `node:assert/strict`
- Fixture strategy: temp directories plus temp `HOME`
- Command execution: spawn the CLI entrypoint directly for integration checks

### Recommended checks for this phase

- CLI contract tests: usage, invalid args, exit codes
- Registry tests: add, remove, dedupe, missing path rejection
- Integration smoke tests: local entrypoint can mutate a temp registry through documented commands

### Risks To Watch

- Storing raw input rather than canonical paths
- Printing success messages to the wrong stream in a way that complicates future wrapper integration
- Assuming package-level install behavior without testing the actual bin entrypoint

## Planning Implications

- Plan 1 should lock the CLI contract and package entrypoint first.
- Plan 2 should implement registry logic and mutation behavior.
- Plan 3 should prove the repo-local install path and add a smoke harness.

---

*Phase research completed: 2026-03-12*
