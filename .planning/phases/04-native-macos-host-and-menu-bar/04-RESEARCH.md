# Phase 4 Research: Native macOS Host And Menu Bar

**Date:** 2026-03-14
**Status:** Complete

## Objective

Answer: what do we need to know before planning a native menu bar launcher for `goto`?

## Key Findings

### 1. `MenuBarExtra` is the right native surface for the first menu bar cut

Apple's SwiftUI documentation positions `MenuBarExtra` as the native API for menu bar utilities on macOS. That matches the requested interaction better than trying to keep a terminal TUI permanently resident.

- It gives us a clear product surface for the saved project list.
- It keeps the menu bar experience separate from the shell wrapper implementation.
- It points the project toward a real app host, which Finder work will need anyway.

### 2. The shell registry can stay as the cross-surface contract

The current Node implementation already persists projects in `~/.goto` and exposes the behaviors the new surfaces care about: stable ordering, path existence checks, and canonical absolute paths.

- Reusing the registry avoids migration work right now.
- Native code can read the same file without taking a Node runtime dependency.
- The menu bar does not need to own registration to be useful in the first cut.

### 3. Terminal handoff is a platform-permission problem as much as an implementation problem

Opening or reusing Terminal from a native host will likely depend on macOS automation or scriptable app control. That means the first validation pass needs to include permission prompts and failure states, not only happy-path launch behavior.

- We should build one reusable launch bridge and make Finder reuse it later.
- We should expect manual validation for permission prompts on a clean machine.

### 4. Full Xcode is a practical prerequisite

This environment has Swift available, but `xcodebuild` resolves only to Command Line Tools and cannot build a proper macOS app target or Finder extension target yet.

- Phase 4 planning can proceed now.
- Phase 4 execution will need Xcode.app selected as the active developer directory.

## Source Notes

- Apple Developer Documentation: `MenuBarExtra`
  - <https://developer.apple.com/documentation/swiftui/menubarextra>
- Apple Developer Documentation: Finder Sync
  - <https://developer.apple.com/documentation/findersync>
- Apple Developer Documentation: App Extension Programming Guide
  - <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/>

## Validation Architecture

### Recommended checks for this phase

- Verify the native app can read and render the `~/.goto` registry.
- Verify missing paths are surfaced without crashing the menu bar UI.
- Verify Terminal launch behavior on:
  - Terminal not running
  - Terminal already running
  - automation permission denied

### Risks To Watch

- Accidentally forking registry semantics between Node and Swift
- Treating Terminal automation as a pure code path without permission-aware UX
- Starting Finder work before the shared native launch bridge exists

## Planning Implications

- Plan 1 should create the native host shell and shared registry reader.
- Plan 2 should render the menu bar project list and broken-entry states.
- Plan 3 should finish the Terminal handoff path and native smoke verification.

---

*Phase research completed: 2026-03-14*
