# Requirements: goto

**Defined:** 2026-03-12
**Core Value:** From anywhere in macOS, get to the right project directory in one quick, low-friction interaction.

## v1 Requirements

### Shell Integration

- [x] **SHL-01**: User can run `goto`, select a project, and land in that directory in the current `zsh` session
- [x] **SHL-02**: User can run `goto`, select a project, and land in that directory in the current `bash` session
- [x] **SHL-03**: User can press `Esc` during selection and remain in the current directory without side effects
- [x] **SHL-04**: User sees a clear error instead of a broken `cd` when selection fails or no valid project is returned

### Registry Management

- [x] **REG-01**: User can run `goto -a` to register the current working directory
- [x] **REG-02**: User can run `goto -a PATH` to register a specific directory path
- [x] **REG-03**: User can run `goto -r` to remove the current working directory from the registry
- [x] **REG-04**: User can run `goto -r PATH` to remove a specific directory path from the registry
- [x] **REG-05**: User cannot create duplicate registrations for the same canonical directory
- [x] **REG-06**: User receives a clear message when trying to add or remove an invalid or missing directory

### Picker Experience

- [x] **PICK-01**: User can open a list of registered projects by running `goto` with no arguments
- [x] **PICK-02**: User can move selection up and down with the keyboard
- [x] **PICK-03**: User can press `Enter` to choose the highlighted project
- [x] **PICK-04**: User can see both the project name and its full path in the picker
- [x] **PICK-05**: User can distinguish missing or unusable project paths before trying to open them
- [x] **PICK-06**: User sees projects in a stable, predictable order across sessions

### Install And Setup

- [x] **INST-01**: User can install and use `goto` locally from this repository without publishing a package
- [x] **INST-02**: User can enable `goto` in `zsh` by sourcing a documented shell integration snippet
- [x] **INST-03**: User can enable `goto` in `bash` by sourcing a documented shell integration snippet

### Native macOS Surfaces

- [x] **APP-01**: Native macOS surfaces and the shell workflow use the same local project registry without duplicate sources of truth
- [x] **MB-01**: User can open a menu bar entry point and see the registered projects list without opening a shell first
- [x] **MB-02**: User can choose a saved project from the menu bar and open it in Terminal
- [x] **MB-03**: If Terminal is already open, the chosen project opens in the active Terminal context instead of forcing a second disconnected flow
- [x] **MB-04**: The menu bar surface shows or safely disables missing project paths instead of silently failing
- [x] **FDR-01**: User can invoke a Finder surface on a selected folder to open that folder in Terminal
- [x] **FDR-02**: The Finder flow works for normal project paths including spaces and non-ASCII characters
- [x] **FDR-03**: Invalid or missing Finder selections fail with clear feedback instead of a broken Terminal state
- [x] **FDR-04**: Finder-triggered launch reuses the same Terminal handoff behavior as the menu bar flow

### Visual Polish

- [x] **UI-01**: User sees a restrained, polished terminal UI rather than raw default prompt output
- [x] **UI-02**: User gets useful empty-state and confirmation copy for first-run, add, and remove flows

## v2 Requirements

### Search And Metadata

- **META-01**: User can filter the project list with typed search
- **META-02**: User can assign aliases, tags, or favorites to saved projects

### Distribution

- **DIST-01**: User can install `goto` as a published package instead of only from the local repository
- **DIST-02**: User can use `goto` in shells beyond `zsh` and `bash`

## Out of Scope

| Feature | Reason |
|---------|--------|
| Team-shared registry sync | v1 is intentionally local-first and single-user |
| Cloud backup | Adds infrastructure outside the core jump workflow |
| Fuzzy search | Useful later, but not required to validate the core interaction |
| Tags, groups, favorites | Adds metadata and UI surface beyond the minimal cut |
| Shells beyond `zsh` and `bash` | Expands compatibility work before the core product is proven |
| Package publishing | Local install is enough for the first release |
| Alternate terminals beyond Terminal.app | Defer until the default Terminal flow is proven end-to-end |
| Team-shared launch state or presence sync | Native launcher surfaces still stay local-first in the first cut |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHL-01 | Phase 2 | Done |
| SHL-02 | Phase 2 | Done |
| SHL-03 | Phase 2 | Done |
| SHL-04 | Phase 2 | Done |
| REG-01 | Phase 1 | Done |
| REG-02 | Phase 1 | Done |
| REG-03 | Phase 1 | Done |
| REG-04 | Phase 1 | Done |
| REG-05 | Phase 1 | Done |
| REG-06 | Phase 1 | Done |
| PICK-01 | Phase 2 | Done |
| PICK-02 | Phase 2 | Done |
| PICK-03 | Phase 2 | Done |
| PICK-04 | Phase 2 | Done |
| PICK-05 | Phase 2 | Done |
| PICK-06 | Phase 2 | Done |
| INST-01 | Phase 1 | Done |
| INST-02 | Phase 3 | Done |
| INST-03 | Phase 3 | Done |
| UI-01 | Phase 3 | Done |
| UI-02 | Phase 3 | Done |
| APP-01 | Phase 4 | Done |
| MB-01 | Phase 4 | Done |
| MB-02 | Phase 4 | Done |
| MB-03 | Phase 4 | Done |
| MB-04 | Phase 4 | Done |
| FDR-01 | Phase 5 | Done |
| FDR-02 | Phase 5 | Done |
| FDR-03 | Phase 5 | Done |
| FDR-04 | Phase 5 | Done |

**Coverage:**
- v1 requirements: 30 total (30 Done)

---
*Requirements defined: 2026-03-12*
*Last updated: 2026-03-24 — v1.0 complete, v1.1 hardening scrapped, three-package refactoring shipped*
