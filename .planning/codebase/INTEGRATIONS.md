# External Integrations

**Analysis Date:** 2026-03-20

## APIs & External Services

**macOS shell and Terminal launch surface:**
- Terminal.app - the native launch path opens Terminal with AppleScript first, then falls back to `open -a Terminal` in `native/Sources/GotoNativeCore/TerminalLauncher.swift` and `native/Sources/GotoNativeCore/TerminalScriptBuilder.swift`
  - SDK/Client: Foundation `Process` in `native/Sources/GotoNativeCore/TerminalLauncher.swift`
  - Auth: macOS Apple Events permission; no repository-managed secret or env var is used

**Finder integration:**
- Finder Sync extension - the toolbar button and Finder menu surface are implemented in `macos/GotoFinderSync/GotoFinderSyncExtension.swift` with bundle metadata in `macos/GotoFinderSync/Info.plist`
  - SDK/Client: `FinderSync.framework`, `AppKit`, and `NSWorkspace` from `macos/GotoFinderSync/GotoFinderSyncExtension.swift`
  - Auth: user-enabled Finder extension state plus sandbox entitlements in `macos/GotoFinderSync/GotoFinderSync.entitlements`

**Host-app callback bridge:**
- Custom URL callback + distributed notifications - the extension calls the host app through `goto-host://...` URLs and shares Finder observation events through `DistributedNotificationCenter` in `macos/Shared/FinderLaunchNotifications.swift`, `macos/GotoHost/Info.plist`, and `macos/GotoHost/FinderLaunchBridge.swift`
  - SDK/Client: `SwiftUI`, `FinderSync`, `Foundation`, and `DistributedNotificationCenter` in `macos/GotoHost/GotoHostApp.swift` and `macos/GotoHost/FinderLaunchBridge.swift`
  - Auth: macOS app-launch and Apple Events permission model; no repository-managed secret or env var is used

**Legacy Finder service surface:**
- Automator / Services workflow - repository scripts still generate and install a Finder Quick Action style workflow from `scripts/render-finder-workflow.sh`, `scripts/install-finder-action.sh`, and `scripts/test-finder-action.sh`
  - SDK/Client: Automator workflow bundle, `/System/Library/CoreServices/pbs`, and `/usr/bin/osascript` referenced in `scripts/render-finder-workflow.sh`
  - Auth: no secret-backed auth; optional customization uses `GOTO_FINDER_WORKFLOW_NAME`, `GOTO_FINDER_BUNDLE_ID`, and `GOTO_WORKFLOW_LAUNCH_ARGS` in `scripts/render-finder-workflow.sh`

## Data Storage

**Databases:**
- None detected
  - Connection: Not applicable
  - Client: Not applicable

**File Storage:**
- Local filesystem only
  - The project registry is stored as `~/.goto` and resolved by `src/paths.js`, `src/registry.js`, and `native/Sources/GotoNativeCore/RegistryStore.swift`
  - Native app bundles are built into `build/GotoMenuBar.app` and `build/macos-products/Debug/GotoHost.app` through `scripts/build-menu-bar-app.sh` and `scripts/build-finder-toolbar-host.sh`
  - Finder host installs into `~/Applications/GotoHost.app` via `scripts/install-finder-toolbar-host.sh`

**Caching:**
- None detected

## Authentication & Identity

**Auth Provider:**
- Custom / OS-managed permissions
  - Implementation: the code relies on macOS Finder extension enablement and Apple Events approval rather than an identity provider, with permission handling in `macos/GotoHost/GotoHostApp.swift`, `macos/GotoHost/FinderLaunchBridge.swift`, and `native/Sources/GotoNativeCore/TerminalLauncher.swift`

## Monitoring & Observability

**Error Tracking:**
- None detected

**Logs:**
- Temporary local file logging in `macos/GotoHost/FinderLaunchBridge.swift`, which appends diagnostic lines to `NSTemporaryDirectory()/goto-finder-bridge.log`
- CLI and native command messaging are emitted to stdout/stderr from `src/output.js` and `native/Sources/GotoNativeLaunch/main.swift`

## CI/CD & Deployment

**Hosting:**
- Local machine install only
  - Shell integration appends `source` lines into `~/.zshrc` or `~/.bashrc` from `scripts/install-shell.sh`
  - The menu bar app is packaged as `build/GotoMenuBar.app` by `scripts/build-menu-bar-app.sh`
  - The Finder toolbar host is built from `macos/Goto.xcodeproj` and installed into `~/Applications/GotoHost.app` by `scripts/install-finder-toolbar-host.sh`

**CI Pipeline:**
- Not detected (`.github/`, Docker deployment manifests, and other hosted CI config files are not detected in the repository scan)

## Environment Configuration

**Required env vars:**
- `HOME` - required to resolve the shared registry path in `src/paths.js` and `native/Sources/GotoNativeCore/RegistryStore.swift`
- `DEVELOPER_DIR` - optional override for native toolchain resolution in `scripts/test-native.sh`, `scripts/run-native-menu-bar.sh`, `scripts/run-native-launch.sh`, `scripts/build-menu-bar-app.sh`, and `scripts/build-finder-toolbar-host.sh`
- `NO_COLOR` - optional terminal UI toggle in `src/select.js`
- `SHELL` and `ZDOTDIR` - optional shell-install routing in `scripts/install-shell.sh`
- `GOTO_FINDER_WORKFLOW_NAME`, `GOTO_FINDER_BUNDLE_ID`, and `GOTO_WORKFLOW_LAUNCH_ARGS` - optional legacy Finder workflow generation knobs in `scripts/render-finder-workflow.sh`

**Secrets location:**
- Not detected (`.env*`, credential files, and secret stores are not detected in the repository scan performed for this refresh)

## Webhooks & Callbacks

**Incoming:**
- `goto-host://open?path=...` and `goto-host://current-finder-folder` are registered in `macos/GotoHost/Info.plist` and parsed in `macos/Shared/FinderLaunchNotifications.swift`
- Finder extension launch notifications are consumed through `DistributedNotificationCenter` observers in `macos/GotoHost/FinderLaunchBridge.swift`

**Outgoing:**
- The Finder Sync extension opens the host app through `NSWorkspace.shared.open(...)` in `macos/GotoFinderSync/GotoFinderSyncExtension.swift`
- The Finder Sync extension broadcasts observed-directory lifecycle notifications through `DistributedNotificationCenter` in `macos/GotoFinderSync/GotoFinderSyncExtension.swift`
- No HTTP webhooks or third-party callback endpoints are detected

---

*Integration audit: 2026-03-20*
