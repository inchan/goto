# Cron Governance Workflow

## Inputs

- Current project snapshot.
- Harness validation result.
- Relevant canonical records.

## Outputs

- Canonical artifact path(s) under `.hermes/`.
- Human summary only after canonical data exists.

## Allowed Side Effects

Read-only cron audit by default; no recursive cron creation.

## Stop Conditions

- Required evidence is missing.
- Action classification is blocked or approval-required.
- Manual gate is required.
- Harness readiness check blocks this mode.

## Required Evidence

- File paths or command outputs supporting every claim.
- Explicit residual risk.
