# Codebase Structure

**Analysis Date:** 2026-03-20

## Directory Layout

```text
goto/
├── .omx/                           # OMX runtime state, logs, and session artifacts
├── .planning/                      # Planning artifacts and generated codebase maps
│   └── codebase/                   # Mapper outputs such as `ARCHITECTURE.md`
├── bin/                            # Executable Node bootstrap
├── build/                          # Generated .app bundles and Xcode build outputs
├── macos/                          # Host-app and Finder Sync sources plus generated Xcode project
│   ├── GotoHost/                   # Host app entrypoints and Finder bridge
│   ├── GotoFinderSync/             # Finder Sync extension sources and metadata
│   ├── Shared/                     # Host/extension shared notification and URL contract
│   └── Goto.xcodeproj/             # Generated Xcode project
├── native/                         # SwiftPM package for shared native code and standalone surfaces
│   ├── Sources/GotoNativeCore/     # Shared native registry and launch logic
│   ├── Sources/GotoMenuBar/        # SwiftPM menu bar target
│   ├── Sources/GotoNativeLaunch/   # SwiftPM launcher CLI target
│   └── Tests/                      # XCTest targets
├── scripts/                        # Build, install, uninstall, and verification automation
├── shell/                          # bash/zsh wrappers that can change the caller's cwd
├── src/                            # JavaScript CLI implementation
│   └── commands/                   # CLI verb handlers
├── test/                           # Node tests and process helpers
├── package.json                    # Node package metadata
└── README.md                       # User-facing usage guide
```

## Directory Purposes

**`.omx/`:**
- Purpose: persist OMX orchestration state, logs, and session metadata rather than product runtime code.
- Contains: `.omx/logs/`, `.omx/state/`, `.omx/plans/`, and session snapshots.
- Key files: `.omx/state/session.json`, `.omx/logs/omx-2026-03-19.jsonl`
- Key subdirectories: `.omx/logs/`, `.omx/state/`

**`.planning/`:**
- Purpose: store roadmap, phase documents, research, and generated codebase-map outputs.
- Contains: `.planning/STATE.md`, `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/phases/`, `.planning/research/`, `.planning/codebase/`
- Key files: `.planning/STATE.md`, `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`
- Key subdirectories: `.planning/codebase/`, `.planning/phases/`, `.planning/research/`

**`bin/`:**
- Purpose: hold executable entrypoints.
- Contains: `bin/goto.js`
- Key files: `bin/goto.js`
- Key subdirectories: Not detected

**`build/`:**
- Purpose: collect generated native artifacts and Xcode intermediate outputs.
- Contains: packaged output in `build/GotoMenuBar.app/`, product output in `build/macos-products/`, and intermediates in `build/macos-obj/`
- Key files: `build/GotoMenuBar.app/Contents/Info.plist`
- Key subdirectories: `build/macos-products/`, `build/macos-obj/`

**`macos/`:**
- Purpose: hold the Finder toolbar host application, Finder Sync extension, shared host/extension contracts, and the generated Xcode project.
- Contains: `macos/GotoHost/`, `macos/GotoFinderSync/`, `macos/Shared/`, `macos/Goto.xcodeproj/`
- Key files: `macos/GotoHost/GotoHostApp.swift`, `macos/GotoHost/FinderLaunchBridge.swift`, `macos/GotoFinderSync/GotoFinderSyncExtension.swift`, `macos/Shared/FinderLaunchNotifications.swift`, `macos/Goto.xcodeproj/project.pbxproj`
- Key subdirectories: `macos/GotoHost/`, `macos/GotoFinderSync/`, `macos/Shared/`, `macos/Goto.xcodeproj/`

**`native/`:**
- Purpose: isolate the Swift Package Manager project for shared native logic and standalone native surfaces.
- Contains: `native/Package.swift`, `native/Sources/GotoNativeCore/`, `native/Sources/GotoMenuBar/`, `native/Sources/GotoNativeLaunch/`, `native/Tests/GotoNativeCoreTests/`, `native/Tests/GotoMenuBarTests/`
- Key files: `native/Package.swift`, `native/Sources/GotoNativeCore/RegistryStore.swift`, `native/Sources/GotoNativeCore/TerminalLauncher.swift`, `native/Sources/GotoMenuBar/GotoMenuBarApp.swift`, `native/Sources/GotoNativeLaunch/main.swift`
- Key subdirectories: `native/Sources/GotoNativeCore/`, `native/Sources/GotoMenuBar/`, `native/Sources/GotoNativeLaunch/`, `native/Tests/GotoNativeCoreTests/`, `native/Tests/GotoMenuBarTests/`

**`scripts/`:**
- Purpose: keep operational build, packaging, installation, and verification scripts outside the runtime import graph.
- Contains: shell install scripts, native build/test runners, Finder host packaging scripts, and legacy Finder action scripts.
- Key files: `scripts/install-shell.sh`, `scripts/build-menu-bar-app.sh`, `scripts/build-finder-toolbar-host.sh`, `scripts/install-finder-toolbar-host.sh`, `scripts/generate_macos_project.rb`
- Key subdirectories: Not detected

**`shell/`:**
- Purpose: provide sourced bash/zsh adapters that can change the current shell directory after a successful selection.
- Contains: `shell/goto.zsh`, `shell/goto.bash`
- Key files: `shell/goto.zsh`, `shell/goto.bash`
- Key subdirectories: Not detected

**`src/`:**
- Purpose: implement the JavaScript CLI.
- Contains: argument parsing, output formatting, path normalization, registry persistence, picker UI, and command handlers.
- Key files: `src/cli.js`, `src/output.js`, `src/paths.js`, `src/registry.js`, `src/select.js`, `src/commands/add.js`, `src/commands/remove.js`
- Key subdirectories: `src/commands/`

**`test/`:**
- Purpose: hold Node-based contract, mutation, install, and wrapper tests.
- Contains: `test/cli-contract.test.js`, `test/command-mutations.test.js`, `test/install-smoke.test.js`, `test/registry.test.js`, `test/helpers.js`
- Key files: `test/helpers.js`
- Key subdirectories: Not detected

## Key File Locations

**Entry Points:**
- `bin/goto.js`: Node executable bootstrap
- `src/cli.js`: JavaScript command router
- `shell/goto.zsh`: zsh entry surface
- `shell/goto.bash`: bash entry surface
- `native/Sources/GotoNativeLaunch/main.swift`: standalone Swift launcher CLI
- `native/Sources/GotoMenuBar/GotoMenuBarApp.swift`: SwiftPM menu bar app entrypoint
- `macos/GotoHost/GotoHostApp.swift`: Finder toolbar host app entrypoint
- `macos/GotoFinderSync/GotoFinderSyncExtension.swift`: Finder Sync extension entrypoint

**Configuration:**
- `package.json`: Node package metadata, engine constraint, and test command
- `native/Package.swift`: SwiftPM target graph
- `macos/Goto.xcodeproj/project.pbxproj`: generated Xcode target graph for `GotoHost` and `GotoFinderSync`
- `macos/GotoHost/Info.plist`: host app bundle metadata and `goto-host` URL scheme
- `macos/GotoFinderSync/Info.plist`: Finder Sync extension metadata
- `macos/GotoFinderSync/GotoFinderSync.entitlements`: extension sandbox entitlements

**Core Logic:**
- `src/registry.js`: registry reads, writes, dedupe, removal, and MRU promotion
- `src/paths.js`: path expansion and directory validation
- `src/select.js`: interactive picker rendering and keyboard handling
- `native/Sources/GotoNativeCore/RegistryStore.swift`: native registry reader
- `native/Sources/GotoNativeCore/TerminalLauncher.swift`: Terminal launch service and fallback logic
- `native/Sources/GotoNativeCore/TerminalLaunchCommand.swift`: native CLI boundary
- `macos/GotoHost/FinderLaunchBridge.swift`: host-side Finder request resolution and alert presentation
- `macos/Shared/FinderLaunchNotifications.swift`: host/extension URL and notification contract

**Testing:**
- `test/cli-contract.test.js`: Node CLI output and exit-code contract
- `test/command-mutations.test.js`: add/remove/children behavior and non-TTY selection handling
- `test/install-smoke.test.js`: shell wrapper and installer behavior
- `test/registry.test.js`: registry semantics
- `native/Tests/GotoNativeCoreTests/*.swift`: native shared-domain tests
- `native/Tests/GotoMenuBarTests/MenuBarViewModelTests.swift`: menu bar view-model tests
- `scripts/test-native.sh`: native XCTest runner
- `scripts/test-finder-toolbar-host.sh`: Finder toolbar host smoke test

## Naming Conventions

**Files:**
- `kebab-case.js` for JavaScript modules such as `src/select.js` and `src/commands/add.js`
- `kebab-case.test.js` for Node tests such as `test/install-smoke.test.js`
- `goto.<shell>` for sourced shell wrappers in `shell/goto.zsh` and `shell/goto.bash`
- `PascalCase.swift` for Swift types and entrypoints such as `RegistryStore.swift`, `FinderLaunchBridge.swift`, and `GotoMenuBarApp.swift`
- `Info.plist` and `*.entitlements` for Apple bundle metadata in `macos/`
- Uppercase `*.md` for planning and mapping docs such as `.planning/STATE.md` and `.planning/codebase/ARCHITECTURE.md`

**Directories:**
- short lowercase concern-based root directories such as `src/`, `test/`, `shell/`, `scripts/`, `native/`, and `macos/`
- target-name grouping inside `native/Sources/` such as `native/Sources/GotoNativeCore/`, `native/Sources/GotoMenuBar/`, and `native/Sources/GotoNativeLaunch/`
- product-name grouping inside `macos/` such as `macos/GotoHost/` and `macos/GotoFinderSync/`

## Where to Add New Code

**New CLI feature:**
- Primary code: `src/`
- Command routing: `src/cli.js` and, if it is a verb, `src/commands/`
- Tests: `test/`
- User docs: `README.md`

**New shell behavior:**
- Implementation: `shell/goto.zsh` and `shell/goto.bash`
- Installer updates: `scripts/install-shell.sh`
- Tests: `test/install-smoke.test.js`

**New shared native logic:**
- Implementation: `native/Sources/GotoNativeCore/`
- Tests: `native/Tests/GotoNativeCoreTests/`
- Reuse target: keep menu bar, Finder host, and Finder extension behavior on top of the shared types in `GotoNativeCore`

**New standalone native surface or SwiftPM executable:**
- Implementation: add a new target directory under `native/Sources/`
- Target registration: `native/Package.swift`
- Tests: add or extend a matching target under `native/Tests/`

**New Finder host or extension behavior:**
- Host app UI and URL handling: `macos/GotoHost/`
- Finder extension behavior: `macos/GotoFinderSync/`
- Host/extension shared contracts: `macos/Shared/`
- Project graph generation: `scripts/generate_macos_project.rb`
- Generated project output: `macos/Goto.xcodeproj/project.pbxproj`

**New build, install, or verification workflow:**
- Automation scripts: `scripts/`
- Generated outputs: keep them in `build/` or `native/.build/`; do not hand-place generated artifacts into `src/` or `macos/`

## Special Directories

**`build/`:**
- Purpose: generated app bundles and Xcode build output
- Generated: Yes
- Committed: No

**`native/.build/`:**
- Purpose: SwiftPM build cache and compiled binaries
- Generated: Yes
- Committed: No

**`macos/Goto.xcodeproj/`:**
- Purpose: generated Xcode project for `GotoHost` and `GotoFinderSync`
- Generated: Yes
- Committed: Not detected

**`.planning/codebase/`:**
- Purpose: generated repository map consumed by later GSD steps
- Generated: Yes
- Committed: Not detected

**`.omx/`:**
- Purpose: OMX runtime state and logs
- Generated: Yes
- Committed: No

---

*Structure analysis: 2026-03-20*
