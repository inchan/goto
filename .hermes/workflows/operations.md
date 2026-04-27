# Operations Lane

## Purpose

Run routine `goto` repository operations with evidence: verification, branch/PR loops, CI monitoring, safe merges after approved autonomy boundaries, and release-readiness checks.

This lane is separate from self-improvement and drift. It changes or verifies project state; it should not quietly expand the Hermes harness or rewrite project direction during routine operations.

## Inputs

- Current git status, branch, and remote tracking state
- `scripts/verify.sh` / `scripts/verify.sh --ci`
- GitHub PR/check state when relevant
- Harness preflight for the requested operation
- Applicable release/branch rules from `AGENTS.md`

## Allowed Side Effects

- Reversible repo-local commits on non-main feature branches.
- PR creation and CI monitoring when branch state is clean and checks pass.
- develop merge only when the current autonomy boundary or user instruction allows it.

## Manual Gates

- Release, deploy, tag, main push, or public announcement.
- Real money, account/permission/billing changes, credentials, or external messages.
- User/system side effects: `/Applications` installs, shell rc edits, Finder/plugin restarts, `sudo`, launch agents, service managers.
- Creating, updating, pausing, resuming, or deleting scheduler/cron jobs.

## Standard Loop

1. Check git status, branch, and latest commits.
2. Run harness action preflight for the intended operation.
3. Use a feature branch for writes.
4. Make the smallest change.
5. Run focused tests, then `scripts/verify.sh`; use `--ci` before merge when feasible.
6. Use an independent review for multi-file or boundary-sensitive changes.
7. Commit, push, open PR, watch CI, merge only inside the approved boundary.
8. Re-check develop and rerun standard verification after merge.

## Stop Conditions

- Harness preflight requires a manual gate.
- Worktree is dirty for unrelated reasons.
- CI or local verification fails and the failure is not understood.
- The next step belongs to self-improvement or project drift and should be split out.

## Required Evidence

- Commands run and their pass/fail state.
- PR URL/check URL when applicable.
- Final branch/status summary.
- Explicit rollback boundary for changed repo state.
