# Hermes Project Operating System

## Purpose

This file defines how a future goto project commander operates. It is a convenience surface, not canonical truth. Canonical records live in `.hermes/runs/`, `.hermes/events/`, `.hermes/state/`, and `.hermes/derived/`.

## Run Sequence

1. Snapshot project state with `.hermes/scripts/snapshot_project.py`.
2. Validate schemas and examples with `.hermes/scripts/validate_harness.py`.
3. Check readiness with `.hermes/scripts/check_harness_ready.py`.
4. Observe repo state and record observations.
5. Classify possible actions as read-only, safe write, verification, manual gate, approval-required, or blocked.
6. Select the smallest safe action or stop with evidence.
7. Execute only if readiness and action classification allow it.
8. Verify mechanically where possible.
9. Review artifact evidence and residual risk.
10. Derive reports from canonical artifacts.

## Stop Conditions

- Main branch product write would be required.
- User-state side effect would be required.
- Manual macOS gate would be required.
- Harness drift is critical.
- No safe action exists.
- Two management-only runs occur without new evidence.

A safe stop is a valid successful outcome when it prevents fake progress.
