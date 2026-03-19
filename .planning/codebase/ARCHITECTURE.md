# Architecture

**Analysis Date:** 2026-03-20

## Pattern Overview

**Overall:** Local-first polyglot utility with a Node CLI for registry mutation and terminal picker flows, plus macOS-native Swift surfaces for menu bar and Finder launches, all coordinated through the shared flat-file registry at `~/.goto`.

**Key Characteristics:**
- `bin/goto.js` and `src/cli.js` are the single JavaScript boundary for terminal usage.
- `shell/goto.zsh` and `shell/goto.bash` are thin adapters that only invoke the CLI and perform parent-shell `cd`.
- `src/registry.js` is the write authority for `~/.goto`; native code in `native/Sources/GotoNativeCore/RegistryStore.swift` reads the same file but does not mutate it.
- Native surfaces split into SwiftPM targets in `native/Sources/GotoMenuBar/` and `native/Sources/GotoNativeLaunch/`, plus an Xcode host/extension pair in `macos/GotoHost/` and `macos/GotoFinderSync/`.
- `scripts/generate_macos_project.rb` rebuilds `macos/Goto.xcodeproj/project.pbxproj` and wires shared source files from `native/Sources/GotoNativeCore/` directly into the host and Finder Sync targets.

## Layers

**Terminal Surface Layer:**
- Purpose: expose `goto` as an executable and as sourced shell functions that can change the caller's working directory.
- Location: `bin/`, `shell/`, `scripts/install-shell.sh`
- Contains: `bin/goto.js`, `shell/goto.zsh`, `shell/goto.bash`, `scripts/install-shell.sh`
- Depends on: `src/cli.js`
- Used by: direct terminal invocations and shell startup files

**JavaScript CLI Layer:**
- Purpose: parse argv, manage the registry, render the picker, and preserve stdout/stderr contracts.
- Location: `src/`
- Contains: `src/cli.js`, `src/commands/add.js`, `src/commands/remove.js`, `src/select.js`, `src/registry.js`, `src/paths.js`, `src/output.js`
- Depends on: Node built-ins such as `node:fs`, `node:path`, `node:os`, `node:tty`, and `node:readline`
- Used by: `bin/goto.js`, `shell/goto.zsh`, `shell/goto.bash`, and Node tests in `test/`

**Native Shared Domain Layer:**
- Purpose: model saved projects, validate Finder selections, and encapsulate Terminal launch behavior for every native surface.
- Location: `native/Sources/GotoNativeCore/`
- Contains: `native/Sources/GotoNativeCore/RegistryStore.swift`, `ProjectEntry.swift`, `ValidatedDirectory.swift`, `FinderSelection.swift`, `FinderErrorPresenter.swift`, `TerminalLaunchRequest.swift`, `TerminalLaunchCommand.swift`, `TerminalScriptBuilder.swift`, `TerminalLauncher.swift`, `TerminalLaunchError.swift`
- Depends on: `Foundation`
- Used by: `native/Sources/GotoMenuBar/`, `native/Sources/GotoNativeLaunch/main.swift`, and generated Xcode targets in `macos/`

**Native Surface Layer:**
- Purpose: provide GUI and Finder entry points that launch Terminal without calling back into the Node CLI.
- Location: `native/Sources/GotoMenuBar/`, `native/Sources/GotoNativeLaunch/`, `macos/GotoHost/`, `macos/GotoFinderSync/`, `macos/Shared/`
- Contains: `native/Sources/GotoMenuBar/GotoMenuBarApp.swift`, `native/Sources/GotoMenuBar/MenuBarViewModel.swift`, `native/Sources/GotoNativeLaunch/main.swift`, `macos/GotoHost/GotoHostApp.swift`, `macos/GotoHost/MenuBarViewModel.swift`, `macos/GotoHost/FinderLaunchBridge.swift`, `macos/GotoFinderSync/GotoFinderSyncExtension.swift`, `macos/Shared/FinderLaunchNotifications.swift`
- Depends on: `GotoNativeCore` concepts and macOS frameworks such as `SwiftUI`, `AppKit`, and `FinderSync`
- Used by: the menu bar app, the Finder Sync toolbar extension, and URL-scheme based launches into `GotoHost.app`

**Tooling and Packaging Layer:**
- Purpose: assemble native deliverables, regenerate the Xcode project, and verify local builds.
- Location: `scripts/`, `native/Package.swift`, `macos/Goto.xcodeproj/`
- Contains: `scripts/build-menu-bar-app.sh`, `scripts/run-native-menu-bar.sh`, `scripts/run-native-launch.sh`, `scripts/build-finder-toolbar-host.sh`, `scripts/install-finder-toolbar-host.sh`, `scripts/test-native.sh`, `scripts/test-finder-toolbar-host.sh`, `scripts/generate_macos_project.rb`, `native/Package.swift`, `macos/Goto.xcodeproj/project.pbxproj`
- Depends on: local Node, SwiftPM, Ruby `xcodeproj`, `xcodebuild`, `pluginkit`, and macOS command-line tooling
- Used by: developers building `build/GotoMenuBar.app` and `~/Applications/GotoHost.app`

## Data Flow

**Shell Jump Flow:**

1. The user sources `shell/goto.zsh` or `shell/goto.bash` and runs `goto` with no arguments.
2. The wrapper resolves the repository root, invokes `node bin/goto.js`, and hands control to `src/cli.js`.
3. `src/cli.js` routes the no-arg invocation to `runSelect()` in `src/select.js`.
4. `src/select.js` loads entries from `src/registry.js`, opens `/dev/tty` when possible, renders the alternate-screen picker, and tracks the highlighted row in memory.
5. On Enter, `src/select.js` calls `promoteRegistryEntry()` in `src/registry.js`, writes the chosen path to stdout, and exits.
6. The shell wrapper captures stdout and performs `cd` in the parent shell.

**Registry Mutation Flow:**

1. The user runs `goto -a`, `goto -A`, `goto --children`, or `goto -r`.
2. `src/cli.js` parses flags and dispatches to `src/commands/add.js` or `src/commands/remove.js`.
3. The command handler calls `src/registry.js`, which uses `src/paths.js` to expand `~`, resolve relative paths, validate directories, and canonicalize symlinks.
4. `src/registry.js` reads `~/.goto`, computes the next entry list, and atomically rewrites the file through a temp-file rename.
5. The command layer formats the result into stable stdout text; no native code participates in this write path.

**Menu Bar Launch Flow:**

1. `native/Sources/GotoMenuBar/GotoMenuBarApp.swift` or `macos/GotoHost/GotoHostApp.swift` creates a `MenuBarViewModel`.
2. The view model loads projects through `RegistryStore.loadProjects()` in `native/Sources/GotoNativeCore/RegistryStore.swift`.
3. Clicking a project creates a `TerminalLaunchRequest` with surface `.menuBar`.
4. `TerminalLauncher.launch(_:)` in `native/Sources/GotoNativeCore/TerminalLauncher.swift` executes AppleScript built by `TerminalScriptBuilder.swift`.
5. If Terminal automation is denied, `TerminalLauncher` falls back to `open -a Terminal <directory>`; otherwise launch errors are surfaced back to the menu bar status message.

**Finder Toolbar Launch Flow:**

1. `macos/GotoFinderSync/GotoFinderSyncExtension.swift` monitors Finder directories, builds the toolbar menu, and opens a `goto-host://` URL for either a selected path or the current Finder folder.
2. `macos/GotoHost/GotoHostApp.swift` receives the URL and forwards it to `FinderLaunchBridge.shared.handle(url:)`.
3. `macos/Shared/FinderLaunchNotifications.swift` defines the URL format and distributed-notification keys shared by the host and extension.
4. `macos/GotoHost/FinderLaunchBridge.swift` resolves the requested directory from the explicit path, the observed Finder directory list, or a fallback Finder AppleScript query.
5. The bridge validates the directory with `native/Sources/GotoNativeCore/FinderSelection.swift`, wraps it in `TerminalLaunchRequest(surface: .finder)`, and launches Terminal through `TerminalLauncher`.
6. User-facing launch and selection failures are mapped by `native/Sources/GotoNativeCore/FinderErrorPresenter.swift` and displayed as `NSAlert` modals.

**State Management:**
- The durable product state is the newline-delimited registry file at `~/.goto`.
- JavaScript in `src/registry.js` owns mutations; native code in `native/Sources/GotoNativeCore/RegistryStore.swift` currently mirrors read-only access.
- Finder-specific transient state lives in memory in `macos/GotoHost/FinderLaunchBridge.swift` (`observedDirectoryPaths`) and `macos/GotoFinderSync/GotoFinderSyncExtension.swift` (`observedDirectories` and `lastAutomaticLaunch`).
- No database, network service, background daemon, or authentication session store is detected.

## Key Abstractions

**Registry Contract:**
- Purpose: represent the saved project list and its ordering across runtimes.
- Examples: `src/registry.js`, `src/paths.js`, `native/Sources/GotoNativeCore/RegistryStore.swift`
- Pattern: shared flat-file contract with JavaScript write authority and Swift read parity

**Shell Adapter:**
- Purpose: bridge child-process selection output into a parent-shell directory change.
- Examples: `goto()` in `shell/goto.zsh`, `goto()` in `shell/goto.bash`
- Pattern: thin adapter that delegates all business logic to `bin/goto.js`

**Terminal Launch Request:**
- Purpose: carry a validated directory plus originating surface into one native launch path.
- Examples: `native/Sources/GotoNativeCore/ValidatedDirectory.swift`, `TerminalLaunchRequest.swift`, `TerminalLauncher.swift`, `TerminalScriptBuilder.swift`
- Pattern: immutable command object plus launcher/service split

**Finder Relay Contract:**
- Purpose: move Finder context from the extension into the host app without linking the extension to the host process directly.
- Examples: `macos/Shared/FinderLaunchNotifications.swift`, `macos/GotoFinderSync/GotoFinderSyncExtension.swift`, `macos/GotoHost/FinderLaunchBridge.swift`
- Pattern: URL-scheme trigger plus distributed-notification side channel

## Entry Points

**Executable CLI:**
- Location: `bin/goto.js`
- Triggers: direct execution of `goto`, `./bin/goto.js`, or `node bin/goto.js`
- Responsibilities: process bootstrap and exit handling

**JavaScript Command Router:**
- Location: `src/cli.js`
- Triggers: every Node CLI invocation
- Responsibilities: parse argv, route commands, print output, and standardize exit codes

**Shell Wrappers:**
- Location: `shell/goto.zsh`, `shell/goto.bash`
- Triggers: sourced shell function execution
- Responsibilities: locate the repository, invoke the CLI, and perform parent-shell `cd`

**Standalone Native Launch CLI:**
- Location: `native/Sources/GotoNativeLaunch/main.swift`
- Triggers: `scripts/run-native-launch.sh` and direct SwiftPM execution
- Responsibilities: parse one folder argument through `TerminalLaunchCommand` and launch Terminal

**SwiftPM Menu Bar App:**
- Location: `native/Sources/GotoMenuBar/GotoMenuBarApp.swift`
- Triggers: `scripts/run-native-menu-bar.sh` and packaging through `scripts/build-menu-bar-app.sh`
- Responsibilities: show saved projects in a menu bar extra and open them in Terminal

**Finder Toolbar Host App:**
- Location: `macos/GotoHost/GotoHostApp.swift`
- Triggers: launching `GotoHost.app`, opening a `goto-host://` URL, and app startup after install
- Responsibilities: run the host menu bar UI, start `FinderLaunchBridge`, and receive Finder-triggered open requests

**Finder Sync Extension:**
- Location: `macos/GotoFinderSync/GotoFinderSyncExtension.swift`
- Triggers: Finder toolbar/menu interaction and directory observation callbacks
- Responsibilities: expose the Finder toolbar icon, infer selected/current folders, and hand requests to the host app

## Error Handling

**Strategy:** validate early in the domain layer, map recoverable failures to structured statuses or typed native errors, and convert them to user-facing text only at the outer UI boundary.

**Patterns:**
- `src/output.js` defines `CliError` and exit codes; `src/cli.js` catches those errors once and prints stable stderr messages.
- `src/registry.js` returns explicit statuses such as `exists`, `missing`, `removed`, and `promoted` for expected no-op states instead of treating them as fatal failures.
- `src/select.js` treats MRU promotion failure as non-fatal so the selected path can still be returned to the shell.
- `native/Sources/GotoNativeCore/TerminalLaunchCommand.swift` maps usage errors, selection errors, and launch errors into exit codes and stderr text.
- `native/Sources/GotoNativeCore/TerminalLauncher.swift` falls back to `/usr/bin/open -a Terminal` when Apple Events permission is denied.
- `macos/GotoHost/FinderLaunchBridge.swift` converts native errors into `NSAlert` dialogs for GUI users.

## Cross-Cutting Concerns

**Logging:** `macos/GotoHost/FinderLaunchBridge.swift` appends debug lines to `NSTemporaryDirectory()/goto-finder-bridge.log`; structured application logging is otherwise not detected.

**Validation:** `src/paths.js` validates and canonicalizes CLI paths, while `native/Sources/GotoNativeCore/FinderSelection.swift` and `macos/GotoFinderSync/GotoFinderSyncExtension.swift` validate native folder selections before launch.

**Authentication:** Not detected.

**Code Sharing:** `native/Sources/GotoNativeCore/` is the shared native boundary; `scripts/generate_macos_project.rb` injects those files into `macos/Goto.xcodeproj/project.pbxproj` so the Xcode host and Finder Sync extension reuse the same launch and registry model.

---

*Architecture analysis: 2026-03-20*
