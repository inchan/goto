# goto

A macOS developer utility for jumping to project directories. One registry, two surfaces: a terminal TUI picker and a unified `Goto.app` that combines the menu bar UI with the Finder toolbar integration host.

## Features

- Interactive terminal picker with keyboard navigation and MRU ordering
- Bulk-register every child directory under a workspace root
- Unified `Goto.app` with a menu bar project list, settings window, and embedded Finder Sync host
- Finder Sync toolbar button that opens folders in terminal directly from Finder
- Auto-detects installed terminal: Terminal, iTerm2, Warp, Ghostty, Alacritty, Kitty
- Configurable Finder click modes: direct open, project list, or both
- File-watch on `~/.goto` keeps every surface in sync without polling
- Zero runtime dependencies (Node side); Xcode-built native app with embedded Finder Sync extension

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
- the installer lays down the CLI payload plus `Goto.app`
- the installer attempts shell integration automatically for the logged-in user
- if shell integration is skipped, run `goto-install-shell` manually
- remove the packaged install later with `sudo goto-uninstall` (`--purge` also deletes `~/.goto` and `~/.goto-settings`)

If Apple signing/notarization secrets are unavailable, the GitHub workflow falls back to an **unsigned prerelease** package: `goto-<version>-unsigned.pkg`.
Users can still install it, but macOS will require manual approval in **Privacy & Security → Open Anyway**.
The signed/notarized public-release path is deferred until an Apple Developer Program account is available.

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

## Goto App

`Goto.app` is the native host app. It stays in the menu bar, shows the shared project list, exposes Finder-related settings, and embeds the Finder Sync extension host process.

Build and run:

```sh
./scripts/build-app.sh                # produces build/macos-products/Release/Goto.app
open build/macos-products/Release/Goto.app
```

Install to `~/Applications` for local development:

```sh
./scripts/install-app.sh
```

This builds `Goto.app`, copies it to `~/Applications/Goto.app`, registers the Finder Sync extension, restarts Finder, and opens the Extensions preference pane so you can verify the extension is enabled.

Uninstall the local app build:

```sh
./scripts/uninstall-app.sh
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

The Finder Sync extension runs in a sandbox and communicates with `Goto.app` via `DistributedNotificationCenter`. The host app broadcasts the project list and preferences to the extension. The extension posts launch requests back to the host, which performs the actual terminal open.

## Registry

`~/.goto` -- one absolute path per line. Shared by the CLI and `Goto.app`. Safe to edit by hand.

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
| `generate-app-icon.sh` | Generate `macos/Resources/Goto.icns` from the SVG source |
| `build-app.sh` | Build `Goto.app` via `xcodebuild` |
| `build-pkg.sh` | Build a single installer package containing CLI + `Goto.app` |
| `uninstall.sh` | Remove the packaged install from `/Applications` and `/usr/local` |
| `install-app.sh` | Build `Goto.app`, install to `~/Applications`, register extension |
| `uninstall-app.sh` | Remove `~/Applications/Goto.app` and unregister extension |
| `test-app.sh` | Install and smoke-test `Goto.app` |
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
  native/                Swift package (shared core + legacy menu bar target)
    Sources/
      GotoNativeCore/    Shared library: registry, terminal launch, settings, Finder types
      GotoNativeLaunch/  CLI for Finder-triggered folder handoff
      GotoMenuBar/       Legacy standalone menu bar executable
    Tests/               XCTest suites for core and legacy menu bar logic
  macos/                 Xcode project for Goto + GotoFinderSync extension
    Goto/                Unified app host (menu bar UI + settings window)
    FinderBridge/        Finder launch bridge implementation used by the host app
    GotoFinderSync/      Finder Sync extension (FIFinderSync subclass)
  scripts/               Build, install, and test scripts
```

The Node CLI and `Goto.app` share `~/.goto` as the single source of truth. `Goto.app` watches both `~/.goto` and `~/.goto-settings` to keep the menu bar UI and Finder Sync extension in sync.

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

Build `Goto.app` (requires Xcode):

```sh
./scripts/build-app.sh
```

## Documentation

- [CLAUDE.md](CLAUDE.md) — AI context file (loaded by Claude Code on every session)
- [docs/distribution-checklist.md](docs/distribution-checklist.md) — distribution packaging checklist and recommended single-package path
- [docs/github-release.md](docs/github-release.md) — GitHub Actions release flow, required secrets, and `v0.0.1` release steps
- [docs/adr/](docs/adr/) — Architecture Decision Records
