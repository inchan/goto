---
phase: 4
status: ready_for_review
updated: 2026-03-18
---

# Phase 4 Verification

## Automated Evidence

- `./scripts/test-native.sh` passed
- `./scripts/build-menu-bar-app.sh` created `build/GotoMenuBar.app`
- `open build/GotoMenuBar.app` launched the menu bar process and `pgrep -x GotoMenuBar` returned a live PID
- `./scripts/run-native-launch.sh --dry-run "$PWD"` returned the selected directory path
- `node --test` passed

## Verified Outcomes

- The native menu bar host reads the shared `~/.goto` registry through `GotoNativeCore`
- Missing entries are rendered as non-launchable states and are revalidated at click time
- Terminal handoff is centralized in the shared native launch bridge
- The menu bar host can be packaged into a shell-free `.app` bundle from the repository

## Remaining Manual Validation

- Denied Terminal automation permission should be exercised once on this Mac
- A real Terminal-already-open handoff should be observed manually to confirm the reuse semantics

## Verdict

Phase 4 is implementation-complete and **ready for review**. Remaining work is limited to OS-mediated manual validation.
