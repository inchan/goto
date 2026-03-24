---
phase: 5
slug: finder-launch-surface
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-15
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for the Finder toolbar-triggered Terminal launch surface.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | SwiftPM launch bridge tests plus local Xcode Finder Sync host smoke checks |
| **Config file** | `native/Package.swift` and `scripts/generate_macos_project.rb` |
| **Quick run command** | `./scripts/test-finder-toolbar-host.sh` |
| **Full suite command** | `./scripts/test-finder-toolbar-host.sh && ./scripts/test-native.sh && node --test` |
| **Estimated runtime** | ~1-3 minutes once Xcode.app is installed |

---

## Sampling Rate

- **After every task commit:** Run `./scripts/test-finder-toolbar-host.sh`
- **After every plan wave:** Run `./scripts/test-finder-toolbar-host.sh` plus a manual Finder smoke pass
- **Before Phase 5 sign-off:** Re-run the full suite and complete all Finder selection-path checks
- **Max feedback latency:** 10 minutes

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | FDR-01 | generate | `./scripts/build-finder-toolbar-host.sh` | ✅ | ✅ green |
| 05-01-02 | 01 | 1 | FDR-01 | install | `./scripts/install-finder-toolbar-host.sh` | ✅ | ✅ green |
| 05-02-01 | 02 | 2 | FDR-04 | unit | `./scripts/test-native.sh` | ✅ | ✅ green |
| 05-02-02 | 02 | 2 | FDR-02 | smoke | `./scripts/test-finder-toolbar-host.sh` | ✅ | ✅ green |
| 05-03-01 | 03 | 3 | FDR-01 | manual | See manual checks below | ✅ | ⬜ pending |
| 05-03-02 | 03 | 3 | FDR-03 | manual | See manual checks below | ✅ | ⬜ pending |
| 05-03-03 | 03 | 3 | FDR-04 | manual | See manual checks below | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Full Xcode.app is available and can be used through `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- [x] A Finder Sync toolbar host can be generated locally
- [x] The Finder surface reuses the shared native Terminal launch bridge from Phase 4
- [x] The Finder host can be installed and discovered by `pluginkit`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Finder exposes the `goto` toolbar icon on a selected folder | FDR-01 | Finder UI visibility is OS-mediated | Install `GotoHost.app`, open Finder on a monitored folder, and confirm the `goto` toolbar icon is visible in the top bar |
| Clicking the toolbar icon opens Terminal at the selected directory | FDR-01 | Depends on Finder, Terminal, and OS integration state | Select a normal project folder, click the toolbar icon, and verify Terminal lands in that path |
| Paths with spaces work | FDR-02 | End-to-end path quoting cannot be trusted without manual validation | Select a folder whose path contains spaces and verify Terminal lands in the correct directory |
| Paths with non-ASCII characters work | FDR-02 | URL/path encoding must survive Finder-to-Terminal handoff | Select a folder whose path contains non-ASCII characters and verify Terminal lands in the correct directory |
| Invalid or unsupported selections fail clearly | FDR-03 | Finder selection state is not easy to fully automate | Trigger the toolbar flow on an invalid case and verify the user sees a clear failure instead of a broken Terminal state |
| Finder reuses the shared Terminal bridge behavior | FDR-04 | Cross-surface consistency is integration-level | Compare Finder-toolbar launch behavior with the menu bar flow and confirm permission/error handling matches |

---

## Validation Sign-Off

- [x] All tasks have a verification path
- [x] Sampling continuity defined
- [x] Manual-only checks are explicitly documented
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-15
