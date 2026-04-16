# Project Completion Roadmap

**Updated:** 2026-04-17

## Purpose

`goto` is a local-first macOS developer utility for reaching the right project directory with minimal friction. The product has three execution surfaces that share one registry file:

- `goto` CLI and shell integration for changing the active shell directory.
- `Goto.app` menu bar utility for opening saved projects without first opening a shell.
- Finder Sync toolbar extension for opening the current Finder folder in the configured terminal.

The durable product goal is not a larger launcher. It is a small, reliable jump workflow whose native surfaces stay aligned with the same plain-text registry and whose distribution path is testable before release.

## Official Platform Guidance Used

- SwiftUI `MenuBarExtra` is the right primitive for menu bar access to common functionality while the app is inactive. Apple also documents `LSUIElement` for menu-bar-only apps that should not appear in the Dock or app switcher: https://developer.apple.com/documentation/SwiftUI/MenuBarExtra
- Finder Sync is officially framed as a way to modify Finder UI for synchronization status and control, not as a general Finder automation extension. It supports toolbar buttons and shortcut menus, but the extension must be treated as a native convenience surface with OS permission and enablement constraints: https://developer.apple.com/documentation/FinderSync
- `FIFinderSyncProtocol.menu(for:)` is the official hook for returning Finder menus and assigning menu item actions; the selected and targeted Finder items come from `FIFinderSyncController`: https://developer.apple.com/documentation/findersync/fifindersyncprotocol/menu%28for%3A%29
- `SMAppService.mainApp.register()` is the macOS 13+ path for registering the main app as a login item, subject to user approval and status handling: https://developer.apple.com/documentation/servicemanagement/smappservice
- Developer ID distribution requires code signing, hardened runtime, notarization with `notarytool`, and stapling for offline Gatekeeper confidence: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

## What Was Missing

- The local and CI verification story was fragmented. `swift test --package-path product/core` was documented directly, but it failed in sandboxed environments unless Xcode, SwiftPM caches, Clang module caches, and SwiftPM sandboxing were controlled.
- The gate runner and release workflow duplicated verification commands instead of using a single harness.
- `build-app.sh` allowed Xcode to choose default DerivedData under `~/Library`, which makes local agent runs and some CI environments fragile.
- Finder Sync is present in source but is not yet promoted into first-class requirements, acceptance criteria, or a clean manual E2E checklist.
- Signed and notarized public release remains blocked on Apple Developer Program credentials and clean-machine QA.

## Phase 0 — Verification Harness Stabilization

**Status:** Done in this pass.

**Explore:** Read project docs, CLI tests, native core tests, shell install tests, app build scripts, gate workflow, release workflow, and Apple platform documentation.

**Analyze:** The CLI had strong unit and integration coverage, while native verification depended on direct Swift/Xcode defaults that wrote outside the repo and failed under the current sandbox.

**Design:** Use repo-local caches and one verification entry point:

- `scripts/test-native.sh` owns SwiftPM cache, config, security, scratch, Clang module cache, and SwiftPM sandbox settings.
- `scripts/typecheck-native.sh` resolves the Xcode SDK via the same Xcode selection strategy as app builds.
- `scripts/build-app.sh` pins DerivedData under `build/DerivedData`.
- `scripts/verify.sh` becomes the standard local and CI harness.

**Design review:** This keeps the existing zero-dependency posture, avoids new build tooling, and centralizes verification without changing product behavior.

**Plan:** Write failing Node tests for the scripts, update scripts, point workflows to the harness, update docs, then run standard and CI verification.

**Implementation:** Added script-level regression tests, repo-local native caches, unified verification, and workflow wiring.

**Test/verify:** `scripts/verify.sh --standard` and `scripts/verify.sh --ci` pass locally. The CI mode includes app build.

**Review:** Behavior is unchanged; the change reduces environment coupling. Remaining risk is Xcode noise from simulator services in sandboxed local runs, but the build now completes.

## Phase 1 — Finder Sync Product Contract

**Goal:** Decide whether Finder Sync is a supported v1.1 surface or an experimental convenience, then encode that decision in requirements and tests.

**Explore:** Inspect Finder Sync extension behavior, generated Xcode project membership, extension entitlements, Info.plist, and Finder Sync official docs.

**Analyze:** The current extension monitors the home directory and launches from `menu(for:)`. This works as a convenience, but Apple frames Finder Sync around synchronized folders and menu item actions. The product needs explicit acceptance criteria for this deviation.

**Design:** Add a small Finder Sync contract:

- The extension is optional and native-only.
- The toolbar menu resolves selected item first, targeted folder second.
- Missing selection returns a disabled menu item.
- Launch failures are presented with native errors.
- Manual E2E requires enabling the extension in macOS settings.

**Design review:** Keep logic that can be unit-tested in `product/core`; keep OS enablement as manual E2E because Finder extension approval cannot be fully automated in a normal CI runner.

**Plan:** Add Finder Sync requirements to planning docs, add/extend core tests for resolver and launch debouncing, and add a manual Finder E2E checklist.

**Implementation:** Pending.

**Test/verify:** Unit tests plus app build; manual Finder extension enablement and toolbar launch on a clean user account.

**Review:** Confirm the Finder surface still supports the core value without pretending it is a general-purpose Finder automation API.

## Phase 2 — Menu Bar Reliability And Settings Feedback

**Goal:** Make menu bar behavior robust enough for daily use and expose errors that currently disappear.

**Explore:** Inspect `MenuBarViewModel`, `SettingsWindow`, registry watcher, terminal detection, and `SMAppService` behavior.

**Analyze:** Registry loading, missing-path status, and terminal launch errors are handled. Launch-at-login errors are currently swallowed in `SettingsWindow`, even though `SMAppService.register()` can fail or require user approval.

**Design:** Add user-visible settings status for launch-at-login registration, preserve the existing simple settings UI, and keep Service Management interactions isolated.

**Design review:** Do not add a new dependency or a large settings architecture. Extract only the state necessary to test error mapping.

**Plan:** Write tests around status mapping in shared native logic, then update `SettingsWindow` to show success/error copy.

**Implementation:** Pending.

**Test/verify:** Swift unit tests for status mapping, app typecheck, app build, and manual launch-at-login toggle check.

**Review:** Verify no app window appears unexpectedly for the menu-bar-first app.

## Phase 3 — Distribution And Clean Install QA

**Goal:** Make package release evidence repeatable before publishing.

**Status:** Automated package payload smoke is done in this pass; clean-machine installation remains manual.

**Explore:** Inspect `build-pkg.sh`, postinstall, uninstall, release workflow, and notarization docs.

**Analyze:** Package build and unsigned prerelease automation exist. Signed release is blocked on Developer ID certificates and notarization API secrets. Clean-machine QA is still checklist-driven.

**Design:** Keep unsigned prerelease as fallback, but require a package smoke pass before release:

- Build package.
- Inspect package payload paths.
- Verify CLI symlinks and helper scripts.
- Verify checksum creation.
- On signed lane, run notarization and stapling.

**Design review:** Package installation itself needs admin/root and should remain a manual clean-machine gate unless a disposable macOS runner is available.

**Plan:** Add a non-installing package smoke script, wire it into release verification where safe, and keep full install as manual QA.

**Implementation:** Added `scripts/package-smoke.sh` so local runs and the release workflow inspect the package payload before upload.

**Test/verify:** Node tests cover package-smoke success and missing-payload failure. Local package build/smoke should be run before tagging. Manual fresh install on zsh and bash accounts remains the final OS-level QA gate.

**Review:** Confirm uninstall and `--purge` behavior before a public release.

## Phase 4 — v1.1 Release Readiness

**Goal:** Cut a stable release candidate with evidence.

**Explore:** Review all v1/v1.1 requirements, ADRs, README, release notes, and GitHub workflow history.

**Analyze:** A release is complete when CLI, menu bar, Finder optional surface, package, and docs all have traceable acceptance evidence.

**Design:** Use the following release checklist:

- `scripts/verify.sh --ci`
- package smoke
- clean install
- shell integration in zsh and bash
- menu bar registry sync
- Finder extension manual launch
- uninstall
- release notes

**Design review:** Do not promote Finder Sync beyond what was manually verified.

**Plan:** Run the checklist, fix blockers, tag from the version source of truth, and let release workflow publish the package.

**Implementation:** Pending.

**Test/verify:** GitHub gate runner and release workflow, plus manual clean-machine QA evidence.

**Review:** Archive test evidence and known gaps before tagging.

## Phase 5 — v2 Product Expansion

**Goal:** Add search and metadata only after v1.1 surfaces and release flow are stable.

**Explore:** Re-check actual user friction after v1.1 release.

**Analyze:** Current v2 candidates are typed search, aliases, tags, favorites, and additional shell support.

**Design:** Keep `~/.goto` backward-compatible or introduce a migration with a clear fallback.

**Design review:** Do not compromise the single-registry simplicity that makes the product useful.

**Plan:** Write BDD scenarios per user workflow, then implement with TDD in small cuts.

**Implementation:** Pending.

**Test/verify:** CLI unit/integration tests, menu bar registry compatibility tests, and migration tests.

**Review:** Accept only if the default zero-metadata workflow remains just as fast.
