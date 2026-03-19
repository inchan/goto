# Codebase Concerns

**Analysis Date:** 2026-03-20

## Tech Debt

**Legacy Finder Quick Action scripts remain beside the current Finder Sync host path:**
- Issue: the repository still contains the older Automator workflow toolchain even though the current project state says the Finder Quick Action path was replaced by the Finder Sync toolbar host.
- Files: `scripts/render-finder-workflow.sh`, `scripts/install-finder-action.sh`, `scripts/test-finder-action.sh`, `scripts/uninstall-finder-action.sh`, `.planning/STATE.md`
- Impact: contributors can install, test, or maintain the retired Finder surface by accident, which splits attention across two launch implementations.
- Fix approach: remove the retired workflow path or mark it as unsupported legacy tooling with clearly separated docs and scripts.

**Registry mutations are read-modify-write with no cross-process locking:**
- Issue: registry writes always load `~/.goto`, mutate it in memory, then replace the file, but no advisory lock or serialized writer protects overlapping mutations.
- Files: `src/registry.js`, `src/cli.js`, `shell/goto.zsh`, `shell/goto.bash`
- Impact: concurrent `goto -a`, `goto -A`, `goto -r`, or picker-promotion operations can drop updates or reorder entries unexpectedly.
- Fix approach: add a lock or a single-writer mechanism around `~/.goto` mutations before expanding write-capable surfaces.

**Native build/install depends on machine-local Ruby and Xcode state:**
- Issue: Finder host generation requires the `xcodeproj` Ruby gem and local Xcode path discovery that the repository does not bootstrap.
- Files: `scripts/generate_macos_project.rb`, `scripts/build-finder-toolbar-host.sh`, `scripts/build-menu-bar-app.sh`, `scripts/test-native.sh`, `README.md`
- Impact: native build and install flows can fail on clean macOS machines even when the documented Node setup is complete.
- Fix approach: add a reproducible setup step for Ruby/Xcode prerequisites or reduce the dynamic project-generation path.

## Known Bugs

**Live Finder toolbar visibility is still unverified after scripted checks:**
- Symptoms: scripted install and launch checks pass, but the actual Finder toolbar icon presence still requires a manual glance.
- Files: `.planning/STATE.md`, `scripts/test-finder-toolbar-host.sh`, `macos/GotoHost/GotoHostApp.swift`, `macos/GotoFinderSync/GotoFinderSyncExtension.swift`
- Trigger: fresh install into `~/Applications/GotoHost.app` followed by a live Finder session.
- Workaround: run the install flow, open Finder, and manually confirm the toolbar icon is visible and enabled.

## Security Considerations

**The custom URL scheme and notification bridge accept local launch requests without caller verification:**
- Risk: any local process can invoke `goto-host://open?path=...` or post the shared launch notification name to ask the host app to open a local directory in Terminal.
- Files: `macos/GotoHost/Info.plist`, `macos/Shared/FinderLaunchNotifications.swift`, `macos/GotoHost/FinderLaunchBridge.swift`
- Current mitigation: `FinderLaunchBridge` revalidates the path through `FinderSelection`, and `FinderSelection` rejects missing or non-directory targets in `native/Sources/GotoNativeCore/FinderSelection.swift`.
- Recommendations: add request-source hardening if the host app is expected to handle untrusted local callers.

**Finder bridge debug logging writes raw paths into a temp file without rotation or build gating:**
- Risk: selected and opened folder paths are appended to a temp log file and can linger on disk longer than the active session.
- Files: `macos/GotoHost/FinderLaunchBridge.swift`
- Current mitigation: the log is written only to `NSTemporaryDirectory()`.
- Recommendations: gate logging to debug-only builds, redact paths, or rotate and delete the log proactively.

## Performance Bottlenecks

**Registry mutation cost grows linearly with saved entries:**
- Problem: add, remove, promote, and child-add flows canonicalize entries one by one with repeated `fs.stat` and `fs.realpath` calls.
- Files: `src/registry.js`
- Cause: `canonicalizeForCompare` runs inside entry loops for duplicate detection and removals.
- Improvement path: cache normalized paths per operation or persist a canonical form once instead of re-reading the filesystem for every comparison.

**Finder menu rebuild work scales with the full registry:**
- Problem: opening the Finder toolbar menu reloads the registry, filters existing projects, and rebuilds the quick-launch items on demand.
- Files: `macos/GotoFinderSync/GotoFinderSyncExtension.swift`, `native/Sources/GotoNativeCore/RegistryStore.swift`
- Cause: `menu(for:)` loads projects each time, and `monitoredDirectories()` seeds watched URLs from the full registry plus the home directory.
- Improvement path: cache menu data or reduce the monitored URL set so large registries do less work per interaction.

## Fragile Areas

**Current Finder-folder launch depends on observation timing and Apple Events fallback:**
- Files: `macos/GotoHost/FinderLaunchBridge.swift`, `macos/GotoFinderSync/GotoFinderSyncExtension.swift`
- Why fragile: the bridge prefers `observedDirectoryPaths.last`, then falls back to AppleScript against the front Finder window, which depends on Finder state and automation permissions.
- Safe modification: keep the observed-directory notification contract and the permission-denied fallback aligned when changing the launch path.
- Test coverage: no automated tests were detected for `FinderLaunchBridge` or `GotoFinderSyncExtension`.

**Finder toolbar menu rendering has launch side effects with only a one-second debounce:**
- Files: `macos/GotoFinderSync/GotoFinderSyncExtension.swift`
- Why fragile: `menu(for:)` calls `automaticallyOpenSelectedDirectoryIfNeeded` or `automaticallyOpenCurrentFinderFolderIfNeeded` while building menu contents, so repeated menu creation can trigger repeated Terminal launches.
- Safe modification: separate launch decisions from menu rendering before changing debounce or retry behavior.
- Test coverage: no automated tests were detected for the automatic-open path.

**Host install/test scripts restart user applications during verification:**
- Files: `scripts/install-finder-toolbar-host.sh`, `scripts/test-finder-toolbar-host.sh`, `scripts/uninstall-finder-toolbar-host.sh`
- Why fragile: install restarts Finder, test kills Terminal, and both flows assume an interactive developer desktop they can disrupt.
- Safe modification: keep these scripts opt-in and run them against disposable installs or sessions when iterating.
- Test coverage: the scripts exercise live tools, but no automated UI assertion proves the post-restart Finder state.

**The Xcode project is generator-owned and rewritten on every host build:**
- Files: `scripts/generate_macos_project.rb`, `scripts/build-finder-toolbar-host.sh`, `macos/Goto.xcodeproj/project.pbxproj`
- Why fragile: manual edits to the checked-in Xcode project are ephemeral unless the Ruby generator is updated in sync.
- Safe modification: change the generator and immediately rebuild the host app whenever target membership or bundle configuration changes.
- Test coverage: no generator-to-project consistency check was detected.

## Scaling Limits

**Finder toolbar quick-launch capacity is capped at 12 existing projects:**
- Current capacity: `12` entries from `existingProjects.prefix(12)`.
- Limit: saved projects after the first twelve do not appear in the Finder toolbar menu.
- Scaling path: add paging, search, or a handoff into the host app for larger registries.
- Files: `macos/GotoFinderSync/GotoFinderSyncExtension.swift`

**Finder Sync monitoring scope grows with every saved project:**
- Current capacity: the extension monitors the home directory plus every saved registry entry loaded from `~/.goto`.
- Limit: more saved projects expand observation scope and per-open menu work linearly.
- Scaling path: monitor narrower roots or compute launch targets without registering every saved project as a watched directory.
- Files: `macos/GotoFinderSync/GotoFinderSyncExtension.swift`, `native/Sources/GotoNativeCore/RegistryStore.swift`

## Dependencies at Risk

**`xcodeproj` is an external machine dependency outside the Node and Swift package flows:**
- Risk: native Finder-host builds fail when the required Ruby gem is missing or the local Ruby environment differs from expectations.
- Impact: `scripts/build-finder-toolbar-host.sh` cannot regenerate `macos/Goto.xcodeproj`, which blocks host installs and Finder-surface verification.
- Migration plan: bootstrap the Ruby gem as part of setup or replace dynamic Xcode project generation with a repo-managed alternative.
- Files: `scripts/generate_macos_project.rb`, `scripts/build-finder-toolbar-host.sh`, `README.md`

## Missing Critical Features

**Headless verification of Finder toolbar availability is not detected:**
- Problem: current scripts verify build, install, registration, and URL-triggered launch behavior, but they do not prove the primary Finder toolbar affordance is visibly present after install.
- Blocks: unattended release verification for the Finder launch surface and reliable regression detection for the top-bar entry point.
- Files: `.planning/STATE.md`, `scripts/test-finder-toolbar-host.sh`, `macos/GotoHost/GotoHostApp.swift`, `macos/GotoFinderSync/GotoFinderSyncExtension.swift`

## Test Coverage Gaps

**Host bridge and Finder Sync extension code are outside the SwiftPM test surface:**
- What's not tested: URL handling, distributed-notification routing, observed-directory bookkeeping, automatic-open debounce, and Finder-window AppleScript fallback.
- Files: `macos/GotoHost/FinderLaunchBridge.swift`, `macos/GotoFinderSync/GotoFinderSyncExtension.swift`, `native/Tests/GotoNativeCoreTests/TerminalLauncherTests.swift`, `native/Tests/GotoMenuBarTests/MenuBarViewModelTests.swift`
- Risk: Finder-only regressions can ship while `swift test --package-path native` stays green.
- Priority: High

**Interactive picker raw-TTY behavior is not covered by automated keypress tests:**
- What's not tested: alternate-screen rendering, raw-mode cleanup, arrow-key navigation, missing-entry messaging, and resize behavior in `runSelect`.
- Files: `src/select.js`, `test/cli-contract.test.js`, `test/install-smoke.test.js`
- Risk: terminal-state regressions or broken keyboard navigation can slip past the current JS tests.
- Priority: Medium

**Finder host install scripts rely on live desktop behavior rather than isolated assertions:**
- What's not tested: `pluginkit` registration failure modes, Finder restart timing, Terminal restart races, and extension-enable UI outcomes.
- Files: `scripts/install-finder-toolbar-host.sh`, `scripts/test-finder-toolbar-host.sh`, `scripts/uninstall-finder-toolbar-host.sh`
- Risk: install regressions surface only on a live desktop session.
- Priority: High

---

*Concerns audit: 2026-03-20*
