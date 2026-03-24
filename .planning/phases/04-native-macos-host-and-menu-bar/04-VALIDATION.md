---
phase: 4
slug: native-macos-host-and-menu-bar
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-15
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for the native macOS host and menu bar launcher.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | SwiftPM tests plus repo-local menu bar app smoke checks |
| **Config file** | `native/Package.swift` |
| **Quick run command** | `./scripts/test-native.sh` |
| **Full suite command** | `./scripts/test-native.sh && node --test` |
| **Estimated runtime** | ~1-3 minutes once Xcode.app is installed |

---

## Sampling Rate

- **After every task commit:** Run `./scripts/test-native.sh`
- **After every plan wave:** Run `./scripts/test-native.sh` plus a menu bar smoke pass
- **Before Phase 4 sign-off:** Run the full native suite, package the app bundle, and complete all manual launch-path checks
- **Max feedback latency:** 10 minutes

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | APP-01 | build | `./scripts/test-native.sh` | ✅ | ✅ green |
| 04-01-02 | 01 | 1 | APP-01 | smoke | `./scripts/build-menu-bar-app.sh` then `open build/GotoMenuBar.app` | ✅ | ✅ green |
| 04-02-01 | 02 | 2 | MB-01 | unit | `./scripts/test-native.sh` | ✅ | ✅ green |
| 04-02-02 | 02 | 2 | MB-04 | unit | `./scripts/test-native.sh` | ✅ | ✅ green |
| 04-03-01 | 03 | 3 | MB-02 | manual | See manual checks below | ✅ | ⬜ pending |
| 04-03-02 | 03 | 3 | MB-03 | manual | See manual checks below | ✅ | ⬜ pending |
| 04-03-03 | 03 | 3 | MB-03 | manual | See manual checks below | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Full Xcode.app is available and can be used through `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- [x] `native/Package.swift` exists
- [x] A launchable menu bar host exists as `GotoMenuBar`
- [x] Native test targets exist for registry and launch helpers

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Menu bar list renders saved projects | MB-01 | Visual native UI state | Launch the app, confirm the menu bar extra appears, and verify saved projects render from `~/.goto` |
| Missing paths show a disabled or clearly broken state | MB-04 | Native menu state and copy are user-facing | Add one bogus path to `~/.goto`, relaunch, and confirm the menu bar distinguishes it |
| Selecting a project opens Terminal when Terminal is not running | MB-02 | Depends on app automation and OS state | Quit Terminal, pick a project from the menu bar, and verify Terminal opens at that directory |
| Selecting a project reuses the active Terminal context when Terminal is already open | MB-03 | Requires real Terminal state | Open Terminal first, pick a project, and verify the active context changes without a broken second flow |
| Denied automation permission fails gracefully | MB-03 | macOS permission prompts cannot be reliably automated | Reset or deny Terminal automation permission, trigger launch, and confirm the app shows a clear failure state |

---

## Validation Sign-Off

- [x] All tasks have a verification path
- [x] Sampling continuity defined
- [x] Manual-only checks are explicitly documented
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-15
