# ADR-HERMES-001: Harness Boundaries

Status: Accepted

## Context

The project needs a Hermes project-commander harness, but autonomous execution must not outrun observability or safety. The repo is a macOS developer utility where some verification requires OS state, user approval, credentials, or manual clean-machine QA.

## Decision

Hermes autonomy is gated by deterministic harness checks. The harness may observe, classify, plan, validate, and report before it may execute.

### Allowed without extra approval

- Read repository files.
- Generate or update project-local `.hermes/` harness artifacts.
- Run non-mutating harness validators.
- Run repo-local tests and build/typecheck commands when they do not mutate user state.
- Write run artifacts under `.hermes/runs/`, `.hermes/events/`, `.hermes/derived/`, and `.hermes/reports/`.

### Blocked on `main`

- Product code writes.
- Release changes.
- Package/install side effects.
- Any action that creates a commit, tag, push, or release.

### Approval required

- Writes to `~/.goto`.
- Writes to shell rc files.
- Writes to `~/Applications` or `/Applications`.
- `sudo`, `launchctl`, `pluginkit`, `pkill Finder`, app install/uninstall, package install.
- Notarization, signing credentials, credential-store mutation.
- Gateway/service installation or recurring cron activation.

### Manual gates

- Finder Sync enablement in macOS Settings.
- Clean-machine package installation QA.
- Launch-at-login user approval.
- Signed/notarized release readiness.

### Cron policy

- Cron jobs must not create or modify cron jobs from inside cron runs.
- Execution cron must default to local output.
- Human-facing recurring reports require a separate activation checklist.

## Consequences

Safe stop is a successful outcome. A commander run may complete by reporting `blocked`, `manual_gate`, or `no_safe_action` with evidence instead of forcing churn.
