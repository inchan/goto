# Execute Workflow

## Inputs

- Current project snapshot.
- Harness validation result.
- Relevant canonical records.

## Outputs

- Canonical artifact path(s) under `.hermes/`.
- Human summary only after canonical data exists.

## Allowed Side Effects

Only approved `safe_repo_write` changes after readiness passes.

## Stop Conditions

- Required evidence is missing.
- Action classification is blocked or approval-required.
- Manual gate is required.
- Harness readiness check blocks this mode.

## Required Evidence

- File paths or command outputs supporting every claim.
- Explicit residual risk.
