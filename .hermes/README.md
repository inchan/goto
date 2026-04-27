# goto Hermes scaffold

This directory holds project-local Hermes profile and subagent role prompts.

Files:
- `profile.md` — project default behavior and scope
- `operating-lanes.json` — separates Hermes self-improvement, project drift, and operations lanes
- `workflows/self-improvement.md` — improve the local Hermes harness without mixing it with product work
- `workflows/project-drift.md` — reconcile docs/metadata/CI claims with live repo facts
- `workflows/operations.md` — run routine repo verification/branch/PR work with gates
- `agents/research.md` — inspect and ground the problem
- `agents/planner.md` — pick the next small objective
- `agents/implementer.md` — make the code change
- `agents/verifier.md` — run tests / dry-runs / mechanical checks
- `agents/reviewer.md` — assess quality and risks

Current readiness score: 90
Recommended roles: research, planner, implementer, verifier, reviewer

## Stable harness check

Use the aggregate check first. It is the safest current entry point because it runs validation, snapshot, drift, and readiness together without enabling execution:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=.hermes python3 .hermes/scripts/run_harness_checks.py --require-observe --lane operations
```

Expected state on `main`:

```text
operating_state=stable_observe_only
lane=operations status=selected
observe=pass exit_code=0
execute=blocked exit_code=10
require=observe
```

Use the stricter form when a caller must prove execution readiness:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=.hermes python3 .hermes/scripts/run_harness_checks.py --require-execute --lane operations
```

Expected state on `main`: same report, but the command exits non-zero because execution is blocked.

Attach a requested action to the same report before doing any work:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=.hermes python3 .hermes/scripts/run_harness_checks.py --require-observe --lane operations --action "read README.md"
```

The small action gate in `check_harness_ready.py` currently distinguishes:

- `read_only` — observe-safe
- `repo_write` — execute-only, still subject to readiness gates
- `user_or_system_side_effect` — manual gate required
- `scheduler_side_effect` — manual gate required
- `unknown_action` — fail closed/manual gate required

Current execute hardening:

- unknown readiness modes are blocked
- execute requires a known git repository and branch
- execute is blocked on `main`
- execute is blocked outside allowlisted branch prefixes: `hermes/`, `feature/`, `chore/`, `fix/`
- execute is blocked when the working tree is dirty

Current limitations:

- The harness is still advisory; it does not sandbox tools or prevent a caller from bypassing it.
- The JSON schema validator is a lightweight subset validator, not a full JSON Schema engine.
- Dirty-tree policy is intentionally conservative and may block harmless local source edits until committed/stashed.
- Drift detection is still narrow and should be expanded with one tested rule at a time.

Generated local artifacts are ignored by `.hermes/.gitignore`:

- `.hermes/state/project-snapshot.json`
- `.hermes/derived/harness-drift-report.json`
- `.hermes/derived/harness-check-report.json`
- `.hermes/derived/readiness-observe.json`
- `.hermes/derived/readiness-execute.json`
- `.hermes/derived/current-status.json` legacy/latest pointer
