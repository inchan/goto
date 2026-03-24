# Roadmap: goto

## Overview

`goto` is a multi-surface macOS project launcher: CLI picker, menu bar app, and Finder toolbar extension — each installable separately, all sharing a single `~/.goto` registry.

v1.0 shipped all features (Phases 1–5). The codebase was then refactored into three independent packages (ADR-006).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions if needed later

- [x] **Phase 1: Registry And Command Core** - Build the executable contract, path normalization, and add/remove flows
- [x] **Phase 2: Picker And Jump Flow** - Add the interactive selector and parent-shell jump behavior
- [x] **Phase 3: Install And Polish** - Harden setup, fresh-shell usability, and terminal presentation
- [x] **Phase 4: Native macOS Host And Menu Bar** - Add a native menu bar launcher that reuses the project registry and Terminal handoff
- [x] **Phase 5: Finder Launch Surface** - Add a Finder-triggered project handoff into Terminal using the native macOS host

## Phase Details

### Phase 1: Registry And Command Core
**Goal:** Deliver a stable internal command contract and trustworthy local registry behavior for saved projects.
**Depends on:** Nothing (first phase)
**Requirements:** [REG-01, REG-02, REG-03, REG-04, REG-05, REG-06, INST-01]
**Plans:** 3/3 complete

### Phase 2: Picker And Jump Flow
**Goal:** Deliver the main `goto` interaction where a user selects a saved project and lands in it from the current shell.
**Depends on:** Phase 1
**Requirements:** [SHL-01, SHL-02, SHL-03, SHL-04, PICK-01, PICK-02, PICK-03, PICK-04, PICK-05, PICK-06]
**Plans:** 3/3 complete

### Phase 3: Install And Polish
**Goal:** Make `goto` durable across fresh shells and raise the terminal experience to the intended quality bar.
**Depends on:** Phase 2
**Requirements:** [INST-02, INST-03, UI-01, UI-02]
**Plans:** 3/3 complete

### Phase 4: Native macOS Host And Menu Bar
**Goal:** Deliver a native macOS launcher that exposes the saved project list from the menu bar and hands the selected project to Terminal.
**Depends on:** Phase 3
**Requirements:** [APP-01, MB-01, MB-02, MB-03, MB-04]
**Plans:** 3/3 complete

### Phase 5: Finder Launch Surface
**Goal:** Let a user trigger `goto` from Finder on a selected folder and land in Terminal at that directory.
**Depends on:** Phase 4
**Requirements:** [FDR-01, FDR-02, FDR-03, FDR-04]
**Plans:** 3/3 complete

## Progress

| Phase | Status | Completed |
|-------|--------|-----------|
| 1. Registry And Command Core | Complete | 2026-03-15 |
| 2. Picker And Jump Flow | Complete | 2026-03-15 |
| 3. Install And Polish | Complete | 2026-03-15 |
| 4. Native macOS Host And Menu Bar | Complete | 2026-03-18 |
| 5. Finder Launch Surface | Complete | 2026-03-22 |

*All phases complete. Three-package refactoring shipped 2026-03-24 (ADR-006).*
