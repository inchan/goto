# Hermes Harness Observability Workflow Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Build the harness for operating future project-level Hermes commanders: observable, testable, bounded workflows before enabling autonomous execution.

**Architecture:** Treat `.hermes/` as the project-local operating surface, but do not let prose become canonical truth. Create a deterministic foundation first: schemas, event logs, state snapshots, workflow contracts, validators, and small dry-run scripts. Let LLM agents propose and summarize; let code validate, gate, classify, and compute observability status.

**Tech Stack:** Markdown/YAML/JSON artifacts under `.hermes/`; Node.js or Python scripts for validators and reports; existing repo verification commands (`node --test product/cli/test/*.test.js`, `scripts/verify.sh`, `scripts/test-native.sh`, `scripts/typecheck-native.sh`); Hermes profiles/cron only after dry-run evidence exists.

---

## Current Context / Evidence

- Repo: `goto`, a local-first macOS developer utility with CLI, menu bar app, and Finder Sync extension.
- Current branch from `git status`: `main...origin/main`.
- Current `.hermes/` exists but is untracked.
- Existing `.hermes/plan.json` says `signals.tests: false`, but README documents Node and Swift tests. This is already an observability defect: the harness can be confidently wrong.
- Existing `.hermes/profile.md` has broad role prompts and readiness score 90, but lacks measurable operating contracts, event schemas, validation scripts, and stop conditions.
- `docs/planning/ROADMAP.md` contains several manual/OS-gated phases: Finder Sync enablement, launch-at-login, package install, clean-machine QA, notarization. A commander must not convert those into fake automated progress.

## Design Principle

Before running autonomous Hermes as a project operator, build the operator's black box recorder.

The first system should answer:

1. What did Hermes observe?
2. What did it decide?
3. Why did it decide that?
4. What did it change?
5. How was it verified?
6. What stopped it?
7. Was the run useful or noisy?
8. Did the harness itself drift from repo truth?

If those questions are not machine-checkable, do not enable recurring autonomous execution.

---

## Layer Model

### Layer 1 — Canonical Records

Append-only or immutable-per-run artifacts.

Proposed files:

```text
.hermes/state/project-snapshot.json
.hermes/events/YYYY-MM-DD/<run-id>.jsonl
.hermes/runs/<run-id>/run.json
.hermes/runs/<run-id>/observations.json
.hermes/runs/<run-id>/decision.json
.hermes/runs/<run-id>/verification.json
.hermes/runs/<run-id>/review.json
.hermes/runs/<run-id>/artifacts.json
.hermes/decisions/ADR-HERMES-001-harness-boundaries.md
```

Canonical records should be written by scripts or by tightly specified templates.

### Layer 2 — Deterministic Derivations

Computed from canonical records.

Proposed files:

```text
.hermes/derived/current-status.json
.hermes/derived/observability-scorecard.json
.hermes/derived/workflow-health.json
.hermes/derived/harness-drift-report.json
.hermes/reports/latest.md
```

### Layer 3 — Convenience Surfaces

Human-readable reports, summaries, commander prompts, role prompts.

Proposed files:

```text
.hermes/operating-system.md
.hermes/workflows/*.md
.hermes/agents/*.md
.hermes/reports/*.md
```

Rule: Layer 3 may summarize Layer 1/2, but must not be the source of truth.

---

## Roadmap

## Roadmap 0: Freeze Safety Boundaries Before Building

### Task 0.1: Write harness boundary ADR

**Objective:** Define what autonomous Hermes may and may not do in this repo.

**Files:**
- Create: `.hermes/decisions/ADR-HERMES-001-harness-boundaries.md`

**BDD Story:**
- Given the repo is on `main`
- When a commander run evaluates a possible code change
- Then it must classify the action as blocked unless a safe branch/worktree exists

**Required content:**
- Main branch write policy: no code writes on `main`.
- User-state side effect policy: no automatic writes to `~/.goto`, shell rc files, `~/Applications`, `/Applications`, `launchctl`, `pluginkit`, `pkill Finder`, `sudo`, notarization, or credential stores.
- Manual gate policy: Finder Sync enablement, clean install, package install, notarization, launch-at-login user approval are manual/blocked unless explicitly authorized.
- Cron policy: cron jobs must not create cron jobs.
- Run scope policy: one run may complete one small task or produce one blocked diagnostic.

**Acceptance criteria:**
- ADR exists.
- It explicitly lists allowed, blocked, and approval-required actions.
- It defines safe stop as a successful outcome.

### Task 0.2: Define action classification taxonomy

**Objective:** Make every proposed action machine-classifiable before execution.

**Files:**
- Create: `.hermes/schemas/action-classification.schema.json`
- Create: `.hermes/examples/action-classification.safe-doc.json`
- Create: `.hermes/examples/action-classification.blocked-main.json`
- Create: `.hermes/examples/action-classification.manual-gate.json`

**BDD Story:**
- Given a proposed action that touches `/Applications`
- When validation runs
- Then the action is classified as `approval_required` or `blocked`, not `safe_write`

**Classification values:**
- `read_only`
- `safe_repo_write`
- `safe_repo_verify`
- `approval_required`
- `manual_gate`
- `blocked`

**Acceptance criteria:**
- Examples cover at least one safe action, one main-branch block, one manual OS gate.
- Schema requires reason, evidence, affected_paths, and required_approval fields.

---

## Roadmap 1: Canonical Observability Records

### Task 1.1: Define run record schema

**Objective:** Every commander/subagent/cron run has a canonical envelope.

**Files:**
- Create: `.hermes/schemas/run.schema.json`
- Create: `.hermes/examples/run.commander-dry-run.json`

**Required fields:**
- `run_id`
- `started_at`
- `actor`
- `role`
- `trigger_type` (`manual`, `cron`, `delegated`, `dry_run`)
- `workdir`
- `branch`
- `git_status_summary`
- `goal`
- `mode` (`observe`, `plan`, `execute`, `verify`, `review`)
- `outcome` (`completed`, `blocked`, `no_safe_action`, `failed`)
- `artifact_paths`

**Acceptance criteria:**
- A dry-run example validates.
- The schema can represent blocked/no-op runs without pretending failure.

### Task 1.2: Define observation schema

**Objective:** Separate what Hermes observed from what Hermes decided.

**Files:**
- Create: `.hermes/schemas/observation.schema.json`
- Create: `.hermes/examples/observation.repo-state.json`

**Required fields:**
- `source`
- `observed_at`
- `fact`
- `evidence_path`
- `evidence_excerpt`
- `confidence`
- `staleness_risk`

**Acceptance criteria:**
- Observation examples include the known defect: `.hermes/plan.json` says tests false while README documents tests.

### Task 1.3: Define decision schema

**Objective:** Record why a run selected or rejected a task.

**Files:**
- Create: `.hermes/schemas/decision.schema.json`
- Create: `.hermes/examples/decision.blocked-main-branch.json`

**Required fields:**
- `decision_id`
- `run_id`
- `selected_action`
- `alternatives_considered`
- `classification`
- `why_now`
- `why_not_more`
- `stop_condition`
- `expected_verification`

**Acceptance criteria:**
- A decision can select `no_safe_action` with a valid reason.
- A decision must reference observations by id or artifact path.

### Task 1.4: Define verification schema

**Objective:** Prevent evidence-free completion claims.

**Files:**
- Create: `.hermes/schemas/verification.schema.json`
- Create: `.hermes/examples/verification.verify-sh-ci.json`
- Create: `.hermes/examples/verification.manual-gate-needed.json`

**Required fields:**
- `verification_id`
- `run_id`
- `commands_run`
- `manual_checks`
- `result` (`pass`, `fail`, `blocked`, `not_applicable`)
- `evidence_excerpt`
- `residual_risk`

**Acceptance criteria:**
- Manual gate can be represented as blocked, not pass.
- Completion reports must reference verification artifact.

---

## Roadmap 2: Deterministic Validation Harness

### Task 2.1: Add schema validator script

**Objective:** Validate all `.hermes/schemas`, `.hermes/examples`, and latest run artifacts.

**Files:**
- Create: `.hermes/scripts/validate_harness.py`
- Create: `.hermes/tests/test_validate_harness.py`

**BDD Story:**
- Given valid example artifacts
- When `python3 .hermes/scripts/validate_harness.py` runs
- Then it exits 0 and reports all examples valid

**Subtasks:**
1. Write failing test for valid examples.
2. Implement minimal JSON loading and schema validation.
3. Add clear error messages with file paths.
4. Run test.
5. Run validator directly.

**Acceptance criteria:**
- Invalid JSON reports exact path.
- Missing required field reports exact schema and artifact.
- No repo product code is touched.

### Task 2.2: Add project snapshot generator

**Objective:** Generate a machine-readable repo state snapshot before any run.

**Files:**
- Create: `.hermes/scripts/snapshot_project.py`
- Create: `.hermes/tests/test_snapshot_project.py`
- Output: `.hermes/state/project-snapshot.json`

**Snapshot fields:**
- branch
- dirty/untracked status
- known docs present
- test paths present
- verification commands present
- product surfaces present
- current `.hermes/plan.json` signals
- detected inconsistencies

**Acceptance criteria:**
- It detects tests exist in this repo.
- It flags existing `signals.tests: false` as drift.
- It does not run product tests; it only observes structure.

### Task 2.3: Add observability scorecard derivation

**Objective:** Compute whether the harness is safe enough to operate.

**Files:**
- Create: `.hermes/scripts/derive_observability_scorecard.py`
- Create: `.hermes/tests/test_observability_scorecard.py`
- Output: `.hermes/derived/observability-scorecard.json`

**Score categories:**
- `snapshot_freshness`
- `schema_validity`
- `decision_traceability`
- `verification_traceability`
- `stop_condition_coverage`
- `side_effect_guard_coverage`
- `cron_safety`
- `harness_drift`

**Acceptance criteria:**
- Scorecard can fail/warn/pass per category.
- Existing plan drift produces warn/fail until repaired.

### Task 2.4: Add aggregate harness check

**Objective:** One command determines whether autonomous operation is allowed.

**Files:**
- Create: `.hermes/scripts/check_harness_ready.py`
- Create: `.hermes/tests/test_check_harness_ready.py`

**Command:**

```bash
python3 .hermes/scripts/check_harness_ready.py
```

**Exit behavior:**
- Exit 0: observation/planning allowed and execution allowed.
- Exit 10: observation/planning allowed, execution blocked.
- Exit 20: harness invalid, no autonomous run allowed.

**Acceptance criteria:**
- On `main`, execution is blocked unless explicitly in observe/plan mode.
- Drift in `.hermes/plan.json` blocks execution until updated or waived.

---

## Roadmap 3: Workflow Contracts

### Task 3.1: Write operating system contract

**Objective:** Define how commander runs proceed.

**Files:**
- Create or replace: `.hermes/operating-system.md`

**Workflow:**
1. Snapshot project.
2. Validate harness.
3. Observe repo state.
4. Classify possible actions.
5. Select smallest safe action or stop.
6. Execute only if allowed.
7. Verify.
8. Review.
9. Write run artifacts.
10. Derive scorecard/report.

**Acceptance criteria:**
- The contract says no execution before harness validation.
- It defines no-safe-action as valid.
- It requires all final reports to include artifact paths.

### Task 3.2: Define workflow documents

**Objective:** Make each workflow independently understandable and testable.

**Files:**
- Create: `.hermes/workflows/observe.md`
- Create: `.hermes/workflows/plan.md`
- Create: `.hermes/workflows/execute.md`
- Create: `.hermes/workflows/verify.md`
- Create: `.hermes/workflows/review.md`
- Create: `.hermes/workflows/cron-governance.md`

**Acceptance criteria:**
- Each workflow has inputs, outputs, allowed side effects, stop conditions, and required artifacts.
- Execute workflow explicitly depends on successful observe + plan + readiness check.

### Task 3.3: Refine role prompts into contracts

**Objective:** Prevent role prompts from becoming shallow self-confirmation.

**Files:**
- Modify: `.hermes/agents/research.md`
- Modify: `.hermes/agents/planner.md`
- Modify: `.hermes/agents/implementer.md`
- Modify: `.hermes/agents/verifier.md`
- Modify: `.hermes/agents/reviewer.md`

**Required role boundaries:**
- Researcher: read-only, observations only.
- Planner: no implementation, decisions and acceptance criteria only.
- Implementer: only executes approved `safe_repo_write` tasks.
- Verifier: write-forbidden, command evidence only.
- Reviewer: diff/artifact review only, no new feature expansion.

**Acceptance criteria:**
- Every role prompt has forbidden actions.
- Every role prompt has required output schema/path.

---

## Roadmap 4: Observability Reports

### Task 4.1: Generate latest run report

**Objective:** Human-readable report from canonical records.

**Files:**
- Create: `.hermes/scripts/generate_run_report.py`
- Create: `.hermes/tests/test_generate_run_report.py`
- Output: `.hermes/reports/latest.md`

**Report sections:**
- Run summary
- Observed facts
- Decision
- Action classification
- Verification evidence
- Stop condition
- Residual risk
- Next eligible action

**Acceptance criteria:**
- Report generation does not invent facts absent from canonical records.
- Missing verification appears as fail/warn, not omitted.

### Task 4.2: Generate harness drift report

**Objective:** Detect when `.hermes` metadata contradicts repo reality.

**Files:**
- Create: `.hermes/scripts/generate_harness_drift_report.py`
- Create: `.hermes/tests/test_harness_drift_report.py`
- Output: `.hermes/derived/harness-drift-report.json`

**Initial expected drift:**
- `.hermes/plan.json` says tests false while repo has documented test files/commands.

**Acceptance criteria:**
- Drift report identifies this defect.
- It suggests exact artifact to repair, but does not silently overwrite it.

### Task 4.3: Add noise/churn detector

**Objective:** Detect when the harness is producing management work without product value.

**Files:**
- Create: `.hermes/scripts/detect_harness_noise.py`
- Create: `.hermes/tests/test_detect_harness_noise.py`

**Signals:**
- multiple runs with no verification
- repeated planning without execution
- repeated docs-only changes without decision impact
- cron reports with no new evidence
- same blocked condition repeated without escalation

**Acceptance criteria:**
- Detector can emit `pass`, `warn`, `fail`.
- Two consecutive management-only runs produce at least `warn`.

---

## Roadmap 5: Cron and Autonomy Gate, Dry-Run First

### Task 5.1: Define cron prompt templates without scheduling them

**Objective:** Prepare cron workflows without enabling them.

**Files:**
- Create: `.hermes/cron-templates/observer.md`
- Create: `.hermes/cron-templates/reviewer.md`
- Create: `.hermes/cron-templates/operator.md`

**Rules:**
- Observer: read-only, local output only.
- Reviewer: summarize canonical artifacts, no code writes.
- Operator: disabled until harness readiness pass and branch policy satisfied.

**Acceptance criteria:**
- Templates contain `do not create new cron jobs`.
- Templates require `workdir`.
- Templates require local delivery unless explicitly promoted.

### Task 5.2: Add cron preflight checker

**Objective:** Verify a cron job definition before creation.

**Files:**
- Create: `.hermes/scripts/check_cron_template.py`
- Create: `.hermes/tests/test_check_cron_template.py`

**Checks:**
- has absolute workdir
- has no recursive cron creation permission
- has delivery target declared
- has stop/no-safe-action behavior
- has required artifact outputs

**Acceptance criteria:**
- Bad template fails with exact reason.
- Good observer/reviewer templates pass.
- Operator template warns/blocks until readiness gate passes.

### Task 5.3: Manual activation checklist

**Objective:** Explicitly require user approval before scheduling recurring work.

**Files:**
- Create: `.hermes/workflows/activation-checklist.md`

**Checklist:**
- Harness validation passes.
- Drift report is clean or intentionally waived.
- Branch policy satisfied.
- First observer dry-run produced useful evidence.
- First reviewer dry-run produced useful evidence.
- Operator remains disabled unless user explicitly approves.

**Acceptance criteria:**
- No cron is created by this plan.
- Activation is a separate later decision.

---

## Roadmap 6: Repair Existing `.hermes` Metadata After Validators Exist

### Task 6.1: Recompute `.hermes/plan.json`

**Objective:** Fix known false signal only after snapshot/drift tools can prove it.

**Files:**
- Modify: `.hermes/plan.json`
- Modify: `.hermes/profile.md` if score/roles change
- Modify: `.hermes/README.md` if readiness wording changes

**Acceptance criteria:**
- `signals.tests` reflects actual repo state.
- Score explanation is reproducible by snapshot/scorecard tools.
- The correction is referenced in drift report/run report.

### Task 6.2: Add harness maintenance note to project docs only if useful

**Objective:** Avoid polluting product README with agent internals unless necessary.

**Files:**
- Possibly create: `.hermes/README.md` expanded section
- Avoid changing: `README.md` unless user wants public docs to mention Hermes harness

**Acceptance criteria:**
- Product docs stay product-focused.
- Harness docs stay under `.hermes/`.

---

## Validation Commands

Initial harness validation commands after implementation:

```bash
python3 .hermes/scripts/validate_harness.py
python3 .hermes/scripts/snapshot_project.py
python3 .hermes/scripts/derive_observability_scorecard.py
python3 .hermes/scripts/check_harness_ready.py
python3 .hermes/scripts/generate_harness_drift_report.py
python3 .hermes/scripts/generate_run_report.py
```

Repo product verification remains separate:

```bash
node --test product/cli/test/*.test.js
scripts/test-native.sh
scripts/typecheck-native.sh
scripts/verify.sh
scripts/verify.sh --ci
```

Do not run OS/user-state side-effect commands automatically from the harness.

---

## Initial MVP Scope

Build only these first:

1. Boundary ADR.
2. Run/observation/decision/verification schemas.
3. Example artifacts.
4. `snapshot_project.py`.
5. `validate_harness.py`.
6. `check_harness_ready.py`.
7. `operating-system.md`.
8. Drift report that catches the existing `signals.tests: false` defect.

Do not yet create cron jobs.
Do not yet run autonomous operator mode.
Do not yet modify product code.
Do not yet make profile aliases or gateway services.

---

## Risks and Mitigations

### Risk: The harness becomes more important than the product

Mitigation:
- Noise detector.
- Kill condition: two consecutive management-only runs without new evidence.
- Reports must show product impact or blocked reason.

### Risk: LLM summaries become canonical truth

Mitigation:
- Canonical JSON artifacts first.
- Markdown reports are derived only.
- Validators reject missing evidence.

### Risk: Commander acts on stale or wrong `.hermes` metadata

Mitigation:
- Snapshot and drift report before every run.
- Execution blocked on unresolved critical drift.

### Risk: macOS/user-state side effects cause damage

Mitigation:
- Action classification schema.
- Boundary ADR.
- Approval-required list.
- Main branch write block.

### Risk: Too much ceremony for small tasks

Mitigation:
- Commander only for score >= 7 tasks.
- Single-agent path remains default for small direct work.
- No cron until dry-run evidence proves usefulness.

---

## Open Questions

1. Should this harness be implemented in Python for simplicity, or Node.js to align with the CLI test stack?
   - Recommendation: Python under `.hermes/scripts/` is acceptable because it is harness-local, but Node may be preferable if we want zero additional developer assumptions.

2. Should `.hermes/` be committed to the repo?
   - Recommendation: yes for generic harness contracts/schemas/workflows; no for private run logs if they may contain local paths or sensitive output. Add a `.hermes/.gitignore` to separate committed templates from local run artifacts.

3. Should the commander profile be `goto` or a new `goto-commander` runtime profile?
   - Recommendation: defer until dry-run harness passes. Runtime profile creation is an activation step, not foundation.

4. Should cron be local-only or report to the user?
   - Recommendation: local-only until reports prove signal value; one human-facing reviewer can be added later.

---

## Definition of Done for This Plan

The harness foundation is ready when:

- `.hermes` has explicit safety boundaries.
- Every run can produce canonical run/observation/decision/verification artifacts.
- Harness validators pass.
- Snapshot detects repo facts and known drift.
- Readiness checker can block unsafe execution.
- Observability report shows evidence, not just prose.
- No autonomous cron/operator has been enabled yet.

Only after that should we consider creating project profiles, cron jobs, or autonomous commander loops.
