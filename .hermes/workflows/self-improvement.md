# Self-Improvement Lane

## Purpose

Improve Hermes itself for this repository: local harness code, validation tests, role prompts, runbooks, and reusable skills/scripts.

This lane is separate from product work. A self-improvement run must not claim that `goto` product behavior improved unless product files were intentionally changed and product verification passed.

## Inputs

- `.hermes/operating-lanes.json`
- Current harness reports under `.hermes/derived/`
- Failing or missing harness tests
- Repeated manual steps from recent work
- User corrections about agent behavior

## Allowed Side Effects

- Repo-local `.hermes/` source/docs/tests changes on a feature branch.
- Skill patch/create only when the learned procedure is reusable beyond this one repo.
- No scheduler, credential, provider, global config, or delivery-target changes without manual gate.

## Standard Loop

1. State the self-improvement hypothesis.
2. Add or update the smallest harness/test/doc check that exposes the gap.
3. Make the minimal repo-local improvement.
4. Run `.hermes` tests and aggregate observe harness.
5. Run product verification if the improvement is wired into product verification or touches shared scripts.
6. Record the distinction between agent improvement and product behavior.

## Stop Conditions

- The proposed change would modify global Hermes state, credentials, providers, delivery, cron jobs, or user/system state.
- The change broadens the harness without a concrete failure, repeated manual step, or user correction.
- The local harness is dirty or generated artifacts would be committed.

## Required Evidence

- Failing test or explicit gap before the change, when practical.
- Passing `.hermes/tests/test_harness.py` after the change.
- Passing `scripts/verify.sh` when standard verification is affected.
- `git status --short --ignored .hermes` showing only intended source changes and ignored generated state.
