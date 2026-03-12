# Requirements: goto

**Defined:** 2026-03-12
**Core Value:** From any shell, get to the right project directory in one quick, low-friction interaction.

## v1 Requirements

### Shell Integration

- [ ] **SHL-01**: User can run `goto`, select a project, and land in that directory in the current `zsh` session
- [ ] **SHL-02**: User can run `goto`, select a project, and land in that directory in the current `bash` session
- [ ] **SHL-03**: User can press `Esc` during selection and remain in the current directory without side effects
- [ ] **SHL-04**: User sees a clear error instead of a broken `cd` when selection fails or no valid project is returned

### Registry Management

- [ ] **REG-01**: User can run `goto -a` to register the current working directory
- [ ] **REG-02**: User can run `goto -a PATH` to register a specific directory path
- [ ] **REG-03**: User can run `goto -r` to remove the current working directory from the registry
- [ ] **REG-04**: User can run `goto -r PATH` to remove a specific directory path from the registry
- [ ] **REG-05**: User cannot create duplicate registrations for the same canonical directory
- [ ] **REG-06**: User receives a clear message when trying to add or remove an invalid or missing directory

### Picker Experience

- [ ] **PICK-01**: User can open a list of registered projects by running `goto` with no arguments
- [ ] **PICK-02**: User can move selection up and down with the keyboard
- [ ] **PICK-03**: User can press `Enter` to choose the highlighted project
- [ ] **PICK-04**: User can see both the project name and its full path in the picker
- [ ] **PICK-05**: User can distinguish missing or unusable project paths before trying to open them
- [ ] **PICK-06**: User sees projects in a stable, predictable order across sessions

### Install And Setup

- [ ] **INST-01**: User can install and use `goto` locally from this repository without publishing a package
- [ ] **INST-02**: User can enable `goto` in `zsh` by sourcing a documented shell integration snippet
- [ ] **INST-03**: User can enable `goto` in `bash` by sourcing a documented shell integration snippet

### Visual Polish

- [ ] **UI-01**: User sees a restrained, polished terminal UI rather than raw default prompt output
- [ ] **UI-02**: User gets useful empty-state and confirmation copy for first-run, add, and remove flows

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

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHL-01 | Phase 2 | Pending |
| SHL-02 | Phase 2 | Pending |
| SHL-03 | Phase 2 | Pending |
| SHL-04 | Phase 2 | Pending |
| REG-01 | Phase 1 | Pending |
| REG-02 | Phase 1 | Pending |
| REG-03 | Phase 1 | Pending |
| REG-04 | Phase 1 | Pending |
| REG-05 | Phase 1 | Pending |
| REG-06 | Phase 1 | Pending |
| PICK-01 | Phase 2 | Pending |
| PICK-02 | Phase 2 | Pending |
| PICK-03 | Phase 2 | Pending |
| PICK-04 | Phase 2 | Pending |
| PICK-05 | Phase 2 | Pending |
| PICK-06 | Phase 2 | Pending |
| INST-01 | Phase 1 | Pending |
| INST-02 | Phase 3 | Pending |
| INST-03 | Phase 3 | Pending |
| UI-01 | Phase 3 | Pending |
| UI-02 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0

---
*Requirements defined: 2026-03-12*
*Last updated: 2026-03-12 after roadmap creation*
