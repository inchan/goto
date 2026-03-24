# Phase 4 Prework: Swift Native Core Without Xcode

**Date:** 2026-03-15
**Status:** Complete

## Objective

Advance the native macOS work as far as possible before full Xcode is available.

## Completed

- Added a standalone Swift package at `native/`
- Added `GotoNativeCore` models for:
  - project entries
  - shared `~/.goto` registry loading
  - validated directory and Finder selection parsing
  - Terminal AppleScript command generation
  - reusable Terminal launch request modeling
  - Finder-facing error presentation and Terminal launch failure modeling
- Added a lightweight native typecheck script at `scripts/typecheck-native.sh`
- Added Swift tests for registry parsing, project loading, and Terminal script quoting behavior
- Added a `GotoNativeLaunch` executable that reuses the shared Finder selection and Terminal launch bridge
- Added a menu bar app bundle packager at `scripts/build-menu-bar-app.sh`
- Revalidated menu bar project paths at click time so stale entries cannot launch after the filesystem changes

## Files

- `native/Package.swift`
- `native/Sources/GotoNativeCore/ProjectEntry.swift`
- `native/Sources/GotoNativeCore/RegistryStore.swift`
- `native/Sources/GotoNativeCore/ValidatedDirectory.swift`
- `native/Sources/GotoNativeCore/FinderSelection.swift`
- `native/Sources/GotoNativeCore/FinderErrorPresenter.swift`
- `native/Sources/GotoNativeCore/TerminalScriptBuilder.swift`
- `native/Sources/GotoNativeCore/TerminalLaunchError.swift`
- `native/Sources/GotoNativeCore/TerminalLaunchRequest.swift`
- `scripts/typecheck-native.sh`
- `scripts/build-menu-bar-app.sh`
- `scripts/run-native-launch.sh`
- `native/Sources/GotoNativeCore/TerminalLaunchCommand.swift`
- `native/Sources/GotoNativeLaunch/main.swift`
- `native/Tests/GotoNativeCoreTests/RegistryStoreTests.swift`
- `native/Tests/GotoNativeCoreTests/FinderSelectionTests.swift`
- `native/Tests/GotoNativeCoreTests/TerminalLaunchCommandTests.swift`
- `native/Tests/GotoNativeCoreTests/TerminalScriptBuilderTests.swift`
- `native/Tests/GotoNativeCoreTests/TerminalLaunchRequestTests.swift`

## Verification

- `node --test` still passes after adding the native package
- `swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -target x86_64-apple-macosx13.0 -typecheck native/Sources/GotoNativeCore/*.swift` passes for the full source set
- `./scripts/typecheck-native.sh` passes and provides a repeatable non-Xcode verification path for the Swift source set
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path native` passes
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path native --product GotoMenuBar` passes
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./native/.build/debug/GotoMenuBar` launches and stays alive during a short runtime smoke check
- `./scripts/test-native.sh` passes
- `./scripts/run-native-menu-bar.sh` launches and stays alive during a short runtime smoke check
- `./scripts/build-menu-bar-app.sh` creates `build/GotoMenuBar.app`
- `open build/GotoMenuBar.app` starts the menu bar process and `pgrep -x GotoMenuBar` confirms the app is running

## Remaining Blockers

- Global `xcode-select` still points at Command Line Tools, so native commands should keep using `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` until the system default is switched
- Terminal automation will still need one real permission-denied/manual-approval validation pass
- Finder visibility and live trigger UX are now handled in Phase 5, not here

## Why This Matters

This prework is now beyond pure scaffolding: the shared native core is tested, a reusable launch CLI exists, and the menu bar host can be launched as a real `.app` bundle. The remaining work is no longer architecture or packaging, but final macOS interaction validation.

---

*Prework completed: 2026-03-15*
