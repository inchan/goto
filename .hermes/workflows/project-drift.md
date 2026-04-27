# Project Drift Lane

## Purpose

Detect and repair divergence between project truth and project descriptions: README, AGENTS.md, ADRs, `.hermes/plan.json`, workflow docs, CI configuration, generated reports, and live repo facts.

This lane is separate from self-improvement and operations. Its job is reconciliation, not adding new features or running a full PR/release loop unless a small repair is selected.

## Inputs

- `AGENTS.md`, `README.md`, `docs/adr/`
- `.hermes/plan.json`, `.hermes/profile.md`, `.hermes/README.md`
- `.github/workflows/*.yml`
- `scripts/verify.sh` and current test/build commands
- Fresh project snapshot and drift report

## Allowed Side Effects

- Targeted documentation or metadata repairs that make claims match verified repo facts.
- Small harness drift rules with tests, one rule at a time.
- No product behavior changes unless handed off to the operations lane as a separate repo task.

## Standard Loop

1. Snapshot live repo facts.
2. Compare docs/metadata/CI claims against live facts.
3. Classify each mismatch as repair, waive, or escalate.
4. Repair the smallest stale claim or metadata field.
5. Verify with drift report, harness tests, and relevant repo checks.
6. Preserve history: mark stale/waived evidence instead of silently deleting context.

## Stop Conditions

- The mismatch implies a product goal or architecture change rather than a factual doc/metadata repair.
- Evidence is insufficient to decide which source is correct.
- Fixing the drift would require deleting historical records or changing release/user-facing claims without verification.

## Required Evidence

- Exact file path and line or generated report field for each mismatch.
- The live command or file evidence used as truth.
- A post-repair drift/harness result.
