# Roadmap: goto

## Overview

`goto` will ship as a deliberately small local developer utility. The work starts by locking the shell/CLI contract and registry behavior, then adds the interactive picker and jump flow, and finishes with install durability plus the UI polish needed to make the tool feel sharp instead of merely functional.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions if needed later

- [ ] **Phase 1: Registry And Command Core** - Build the executable contract, path normalization, and add/remove flows
- [ ] **Phase 2: Picker And Jump Flow** - Add the interactive selector and parent-shell jump behavior
- [ ] **Phase 3: Install And Polish** - Harden setup, fresh-shell usability, and terminal presentation

## Phase Details

### Phase 1: Registry And Command Core
**Goal:** Deliver a stable internal command contract and trustworthy local registry behavior for saved projects.
**Depends on:** Nothing (first phase)
**Requirements:** [REG-01, REG-02, REG-03, REG-04, REG-05, REG-06, INST-01]
**Success Criteria** (what must be TRUE):
  1. User can add the current directory or an explicit path to the registry without manual file edits.
  2. User can remove the current directory or an explicit path from the registry with clear feedback.
  3. Duplicate registrations are prevented through canonical path handling.
  4. Invalid or missing paths are rejected with clear messaging.
  5. The tool can be run locally from this repository through the chosen install path.
**Plans:** 3 plans

Plans:
- [ ] 01-01: Create the CLI entrypoint and define command/output semantics
- [ ] 01-02: Implement registry storage, canonical path handling, and add/remove behavior
- [ ] 01-03: Wire the local install path and smoke-test command execution from the repo

### Phase 2: Picker And Jump Flow
**Goal:** Deliver the main `goto` interaction where a user selects a saved project and lands in it from the current shell.
**Depends on:** Phase 1
**Requirements:** [SHL-01, SHL-02, SHL-03, SHL-04, PICK-01, PICK-02, PICK-03, PICK-04, PICK-05, PICK-06]
**Success Criteria** (what must be TRUE):
  1. User can open a project picker from `goto` and move through saved entries with the keyboard.
  2. Pressing `Enter` returns exactly one valid target path and changes directories in both `zsh` and `bash`.
  3. Pressing `Esc` cancels cleanly without changing directories.
  4. Missing paths are visible or safely handled instead of causing a broken jump.
  5. The picker consistently shows project name and full path in a stable order.
**Plans:** 3 plans

Plans:
- [ ] 02-01: Add thin `zsh` and `bash` wrappers for parent-shell `cd`
- [ ] 02-02: Build the picker UI and selection/cancel flow
- [ ] 02-03: Handle missing entries, stable ordering, and jump error cases

### Phase 3: Install And Polish
**Goal:** Make `goto` durable across fresh shells and raise the terminal experience to the intended quality bar.
**Depends on:** Phase 2
**Requirements:** [INST-02, INST-03, UI-01, UI-02]
**Success Criteria** (what must be TRUE):
  1. User can follow documented setup steps to enable `goto` in both `zsh` and `bash`.
  2. A fresh shell session can run `goto` successfully after setup.
  3. The picker, empty state, and add/remove feedback feel intentionally designed rather than raw.
  4. Terminal cleanup remains correct on success, cancel, and interruption paths.
**Plans:** 3 plans

Plans:
- [ ] 03-01: Finalize shell setup snippets and installation documentation
- [ ] 03-02: Polish visual hierarchy, empty states, and feedback copy
- [ ] 03-03: Harden terminal cleanup and run release verification in fresh shells

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Registry And Command Core | 0/3 | Not started | - |
| 2. Picker And Jump Flow | 0/3 | Not started | - |
| 3. Install And Polish | 0/3 | Not started | - |
