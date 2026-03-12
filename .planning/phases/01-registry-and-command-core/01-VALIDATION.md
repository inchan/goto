---
phase: 1
slug: registry-and-command-core
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-12
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `node:test` |
| **Config file** | none — built into Node |
| **Quick run command** | `node --test` |
| **Full suite command** | `node --test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `node --test`
- **After every plan wave:** Run `node --test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | INST-01 | unit | `node --test test/cli-contract.test.js` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | INST-01 | integration | `node bin/goto.js --help` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | INST-01 | unit | `node --test test/cli-contract.test.js` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 2 | REG-05 | integration | `node --test test/registry.test.js` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 2 | REG-01 | integration | `node --test test/command-mutations.test.js` | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 2 | REG-06 | integration | `node --test test/registry.test.js test/command-mutations.test.js` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 3 | INST-01 | integration | `rg -n "npm exec goto" README.md` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 3 | INST-01 | integration | `node --test test/install-smoke.test.js` | ❌ W0 | ⬜ pending |
| 01-03-03 | 03 | 3 | INST-01 | integration | `npm install && HOME="$(mktemp -d)" npm exec goto -- --help` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cli-contract.test.js` — CLI contract and usage checks
- [ ] `test/registry.test.js` — registry storage and dedupe checks
- [ ] `test/command-mutations.test.js` — add/remove integration checks
- [ ] `test/install-smoke.test.js` — repo-local install/smoke verification

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | - | All planned Phase 1 behaviors can be automated with temp directories and temp `HOME` | - |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-12
