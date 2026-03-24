# goto

A macOS developer utility for jumping to project directories. Three surfaces, one registry: a terminal TUI picker, a menu bar app, and a Finder toolbar button.

## Features

- Interactive terminal picker with keyboard navigation and MRU ordering
- Bulk-register every child directory under a workspace root
- SwiftUI menu bar app that lists saved projects and opens them in your terminal
- Finder Sync toolbar button that opens folders in terminal directly from Finder
- Auto-detects installed terminal: Terminal, iTerm2, Warp, Ghostty, Alacritty, Kitty
- Configurable Finder click modes: direct open, project list, or both
- File-watch on `~/.goto` keeps every surface in sync without polling
- Zero runtime dependencies (Node side); single SPM package (Swift side)

## Setup

Prerequisites:

- Node 20+
- macOS 13+ (Ventura or later)
- Xcode (for native builds only)

Install shell integration:

```sh
./scripts/install-shell.sh
```

This appends a `source` line to your `~/.zshrc` (or `~/.bashrc`). You can target a specific shell:

```sh
./scripts/install-shell.sh --shell zsh
./scripts/install-shell.sh --shell bash
./scripts/install-shell.sh --all
```

Reload your shell afterward (`source ~/.zshrc` or `source ~/.bashrc`).

## Packaged Release

GitHub Releases are intended to publish a single installer package: `goto-<version>.pkg`.

For the first packaged release (`0.0.1`):

- the packaged CLI still expects **Node 20+** on the target Mac
- the installer lays down the CLI payload plus both apps
- after installation, run `goto-install-shell` to enable shell `cd` integration

If Apple signing/notarization secrets are unavailable, the GitHub workflow falls back to an **unsigned prerelease** package: `goto-<version>-unsigned.pkg`.
Users can still install it, but macOS will require manual approval in **Privacy & Security → Open Anyway**.

See [docs/github-release.md](docs/github-release.md) for the release workflow and required GitHub secrets.

## CLI Usage

Once the shell wrapper is sourced, `goto` is a shell function that `cd`s into the selected project.

```sh
goto                         # open the TUI picker and jump to the selected project
goto -a                      # add the current directory to the registry
goto -a ~/code/my-project    # add a specific directory
goto -A ~/code               # add all direct child directories under ~/code
goto -r                      # remove the current directory from the registry
goto -r ~/code/old-project   # remove a specific directory
goto --help                  # show usage
goto --version               # print version
```

The picker renders in an alternate screen buffer. Use arrow keys to navigate, Enter to confirm, Esc to cancel. The most recently opened project is promoted to the top of the list.

## Menu Bar App

The menu bar app (`GotoMenuBar`) is a standalone SwiftUI app that reads `~/.goto`, displays your saved projects, and opens them in a terminal window on click.

Build and run:

```sh
./scripts/build-menu-bar-app.sh        # produces build/GotoMenuBar.app
open build/GotoMenuBar.app
```

Settings (accessible from the menu bar dropdown):

- **Terminal picker** -- choose which terminal app to open projects in, or leave on Auto to use whichever is detected
- **Launch at Login** -- register with `SMAppService` so the app starts on boot

The app watches `~/.goto` for changes and reloads automatically.

## Finder Integration

`GotoFinder.app` is an Xcode-built headless agent with an embedded Finder Sync extension. It adds a toolbar button to Finder that opens directories in your terminal.

Install:

```sh
./scripts/install-finder.sh
```

This builds the Finder app, copies it to `~/Applications/GotoFinder.app`, registers the Finder Sync extension, restarts Finder, and opens the Extensions preference pane so you can verify the extension is enabled.

Uninstall:

```sh
./scripts/uninstall-finder.sh
```

### Toolbar customization

After installation, right-click the Finder toolbar and choose "Customize Toolbar...". Drag the **goto** icon (terminal symbol) into your toolbar.

### Click modes

The Finder toolbar button behavior is controlled by the click mode setting in `~/.goto-settings`:

| Mode | Behavior |
|------|----------|
| `direct` | Immediately opens the current/selected folder in terminal |
| `list` | Shows a menu of saved projects to choose from |
| `directPlusList` | Opens the current folder and also shows the project list (default) |

### IPC

The Finder Sync extension runs in a sandbox and communicates with the host app via `DistributedNotificationCenter`. The host broadcasts the project list and preferences to the extension. The extension posts launch requests back to the host, which performs the actual terminal open.

## Registry

`~/.goto` -- one absolute path per line. Shared by the CLI, menu bar app, and Finder agent. Safe to edit by hand.

`~/.goto-settings` -- JSON file for native-side preferences. Current shape:

```json
{
  "finder": {
    "clickMode": "directPlusList",
    "enabled": true
  }
}
```

## Scripts

| Script | Purpose |
|--------|---------|
| `install-shell.sh` | Append shell integration to `~/.zshrc` / `~/.bashrc` |
| `build-menu-bar-app.sh` | Build `GotoMenuBar.app` via `swift build` |
| `run-native-menu-bar.sh` | Build and run the menu bar app in one step |
| `build-finder.sh` | Build `GotoFinder.app` via `xcodebuild` |
| `build-pkg.sh` | Build a single installer package containing CLI + menu bar + Finder |
| `install-finder.sh` | Build, install to `~/Applications`, register extension |
| `uninstall-finder.sh` | Remove `~/Applications/GotoFinder.app` and unregister extension |
| `test-finder.sh` | Install and smoke-test the Finder app |
| `run-native-launch.sh` | Build and run `GotoNativeLaunch` with a given path |
| `typecheck-native.sh` | Type-check the Swift package without building |
| `test-native.sh` | Run Swift package tests |
| `current-version.sh` | Print the current project version from `package.json` |
| `generate_macos_project.rb` | Generate the `macos/Goto.xcodeproj` for the Finder app and extension |
| `notarize-pkg.sh` | Submit a built package to Apple notarization and staple it |

## Architecture

```
goto/
  bin/goto.js            CLI entry point (Node)
  src/                   CLI logic: registry, picker, commands
  shell/                 Shell wrappers (zsh, bash) that source into the parent shell
  native/                Swift package (SPM, swift-tools-version 5.8)
    Sources/
      GotoNativeCore/    Shared library: registry, terminal launch, settings, Finder types
      GotoMenuBar/       SwiftUI menu bar executable
      GotoNativeLaunch/  CLI for Finder-triggered folder handoff
    Tests/               XCTest suites for core and menu bar
  macos/                 Xcode project for GotoFinder + GotoFinderSync extension
    GotoFinder/          Headless Finder agent / launch bridge
    GotoFinderSync/      Finder Sync extension (FIFinderSync subclass)
  scripts/               Build, install, and test scripts
```

The Node CLI and the Swift native apps share `~/.goto` as the single source of truth. The menu bar app and Finder agent both use `RegistryWatcher` (GCD file-system events) to reload when the registry changes.

Terminal launches use AppleScript for Terminal.app and iTerm2, and fall back to `open -a` for terminals that do not support AppleScript (Warp, Ghostty, Alacritty, Kitty).

## Development

Run Node tests:

```sh
node --test
```

Run Swift tests:

```sh
swift test --package-path native
```

Type-check Swift without a full build:

```sh
./scripts/typecheck-native.sh
```

Build the Finder app (requires Xcode):

```sh
./scripts/build-finder.sh
```

## Documentation

- [CLAUDE.md](CLAUDE.md) — AI context file (loaded by Claude Code on every session)
- [docs/distribution-checklist.md](docs/distribution-checklist.md) — distribution packaging checklist and recommended single-package path
- [docs/github-release.md](docs/github-release.md) — GitHub Actions release flow, required secrets, and `v0.0.1` release steps
- [docs/adr/](docs/adr/) — Architecture Decision Records
