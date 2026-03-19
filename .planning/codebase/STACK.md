# Technology Stack

**Analysis Date:** 2026-03-20

## Languages

**Primary:**
- JavaScript (ES modules on Node.js `>=20`) - CLI entrypoint and registry picker flow in `bin/goto.js`, `src/cli.js`, `src/select.js`, and the command modules under `src/commands/`
- Swift (Swift tools `5.8`; generated Xcode targets set `SWIFT_VERSION = 5.0`) - native core, menu bar app, Finder launcher CLI, Finder Sync extension, and host app in `native/Package.swift`, `native/Sources/`, and `macos/`

**Secondary:**
- Bash - install, build, run, and verification scripts in `scripts/*.sh`
- Ruby - generated Xcode project creation in `scripts/generate_macos_project.rb`
- XML property lists / entitlements - macOS bundle metadata in `macos/GotoHost/Info.plist`, `macos/GotoFinderSync/Info.plist`, and `macos/GotoFinderSync/GotoFinderSync.entitlements`

## Runtime

**Environment:**
- Node.js `>=20` for the CLI contract declared in `package.json`
- macOS `13.0+` for all native surfaces declared in `native/Package.swift`, `macos/GotoHost/Info.plist`, and `macos/GotoFinderSync/Info.plist`
- Xcode / Apple developer tools for native build scripts that call `xcrun`, `swift`, and `xcodebuild` in `scripts/typecheck-native.sh`, `scripts/test-native.sh`, `scripts/build-menu-bar-app.sh`, and `scripts/build-finder-toolbar-host.sh`

**Package Manager:**
- npm - JavaScript manifest in `package.json`
- Swift Package Manager - native manifest in `native/Package.swift`
- RubyGems - `xcodeproj >= 1.27.0` loaded directly in `scripts/generate_macos_project.rb`
- Lockfile: missing (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Gemfile.lock`, and `Package.resolved` are not detected at the repository root)

## Frameworks

**Core:**
- Node.js standard library only - CLI implementation uses built-in modules from `bin/goto.js`, `src/cli.js`, `src/registry.js`, `src/paths.js`, and `src/select.js`; no npm runtime dependencies are declared in `package.json`
- SwiftUI - menu bar UI and host app UI in `native/Sources/GotoMenuBar/GotoMenuBarApp.swift`, `native/Sources/GotoMenuBar/MenuBarViewModel.swift`, `macos/GotoHost/GotoHostApp.swift`, and `macos/GotoHost/MenuBarViewModel.swift`
- Foundation / AppKit - native registry, Finder bridge, and process execution in `native/Sources/GotoNativeCore/*.swift` and `macos/GotoHost/FinderLaunchBridge.swift`
- FinderSync.framework - Finder toolbar extension and host integration in `macos/GotoFinderSync/GotoFinderSyncExtension.swift` and the generated project settings in `scripts/generate_macos_project.rb`

**Testing:**
- Node built-in test runner - JavaScript test execution via `"test": "node --test"` in `package.json` with suites in `test/*.test.js`
- XCTest - native package tests in `native/Tests/GotoNativeCoreTests/` and `native/Tests/GotoMenuBarTests/`

**Build/Dev:**
- `swift build`, `swift run`, and `swift test` - native compile/run/test workflow in `scripts/run-native-menu-bar.sh`, `scripts/run-native-launch.sh`, and `scripts/test-native.sh`
- `swiftc -typecheck` - lightweight native typecheck in `scripts/typecheck-native.sh`
- `xcodebuild` - Finder toolbar host app build in `scripts/build-finder-toolbar-host.sh`
- `xcodeproj` gem - regenerates `macos/Goto.xcodeproj` from `scripts/generate_macos_project.rb`

## Key Dependencies

**Critical:**
- `xcodeproj >= 1.27.0` - required to generate the checked-in `macos/Goto.xcodeproj` from `scripts/generate_macos_project.rb`
- FinderSync system framework - required for the Finder toolbar extension wired through `macos/GotoFinderSync/GotoFinderSyncExtension.swift` and `macos/GotoFinderSync/Info.plist`
- Terminal / AppleScript tooling - required for native launch handoff implemented in `native/Sources/GotoNativeCore/TerminalLauncher.swift`, `native/Sources/GotoNativeCore/TerminalScriptBuilder.swift`, and `macos/GotoHost/FinderLaunchBridge.swift`

**Infrastructure:**
- Node built-in modules (`node:process`, `node:fs`, `node:path`, `node:os`, `node:readline`, `node:tty`) - used across `bin/goto.js` and `src/*.js`
- Apple command-line tools (`xcrun`, `swift`, `swiftc`, `xcodebuild`, `pluginkit`, `open`, `osascript`, `automator`, `pbs`) - used by `scripts/*.sh` and the native launcher code in `native/Sources/GotoNativeCore/TerminalLauncher.swift`

## Configuration

**Environment:**
- `HOME` is the only consistently required runtime variable; both the CLI and native registry loader derive `~/.goto` from `src/paths.js` and `native/Sources/GotoNativeCore/RegistryStore.swift`
- `NO_COLOR` disables ANSI picker styling in `src/select.js`
- `SHELL` and `ZDOTDIR` influence shell install targets in `scripts/install-shell.sh`
- `DEVELOPER_DIR` overrides Xcode resolution in `scripts/test-native.sh`, `scripts/run-native-menu-bar.sh`, `scripts/run-native-launch.sh`, `scripts/build-menu-bar-app.sh`, and `scripts/build-finder-toolbar-host.sh`
- `GOTO_FINDER_WORKFLOW_NAME`, `GOTO_FINDER_BUNDLE_ID`, and `GOTO_WORKFLOW_LAUNCH_ARGS` customize the legacy Finder workflow generator in `scripts/render-finder-workflow.sh`
- `.env` files are not detected in the repository root or immediate subdirectories scanned during this refresh

**Build:**
- JavaScript entry and test config live in `package.json`
- Swift package config lives in `native/Package.swift`
- Xcode app / extension bundle config lives in `macos/Goto.xcodeproj`, `macos/GotoHost/Info.plist`, `macos/GotoFinderSync/Info.plist`, and `macos/GotoFinderSync/GotoFinderSync.entitlements`

## Platform Requirements

**Development:**
- macOS with Node.js `>=20` to run `./bin/goto.js`, the shell wrappers in `shell/`, and the Node test suite defined in `package.json`
- Apple developer tools (`xcode-select`, `xcrun`, `swift`, `swiftc`, `xcodebuild`) to build and verify the native targets from `native/` and `macos/`
- Ruby with the `xcodeproj` gem to regenerate `macos/Goto.xcodeproj` through `scripts/generate_macos_project.rb`

**Production:**
- Local macOS installation only; there is no server or cloud deployment target detected
- Native menu bar and Finder toolbar surfaces target macOS `13.0+` in `native/Package.swift`, `macos/GotoHost/Info.plist`, and `macos/GotoFinderSync/Info.plist`

---

*Stack analysis: 2026-03-20*
