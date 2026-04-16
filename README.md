# goto

A macOS developer utility for jumping to project directories. One registry, two primary surfaces: a terminal TUI picker and a menu bar `Goto.app`, plus an embedded Finder toolbar extension.

## Features

- Interactive terminal picker with keyboard navigation and MRU ordering
- Bulk-register every child directory under a workspace root
- Menu bar `Goto.app` with a shared project list and settings window
- Finder toolbar button that opens the current Finder folder in Terminal
- Auto-detects installed terminal: Terminal, iTerm2, Warp, Ghostty, Alacritty, Kitty
- File-watch on `~/.goto` keeps every surface in sync without polling
- Zero runtime dependencies on the CLI side; native app built with Xcode

## Setup

Prerequisites:

- Node 20+
- macOS 13+
- Xcode for native app builds

Install shell integration:

```sh
./scripts/install-shell.sh
```

This appends a `source` line to your `~/.zshrc` or `~/.bashrc`.

## Packaged Release

GitHub Releases publish a single installer package: `goto-<version>.pkg`.

Current packaged behavior:

- the packaged CLI still expects Node 20+ on the target Mac
- the installer lays down the CLI payload plus `Goto.app`
- the installer attempts shell integration automatically for the logged-in user
- if shell integration is skipped, run `goto-install-shell` manually
- remove the packaged install later with `sudo goto-uninstall` (`--purge` also deletes `~/.goto`)

If Apple signing or notarization secrets are unavailable, the GitHub workflow falls back to an unsigned prerelease package: `goto-<version>-unsigned.pkg`.

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

## Goto App

`Goto.app` is the native menu bar app. It shows the shared project list, opens projects in the configured terminal, and exposes native settings such as terminal choice and launch-at-login.

Build and run:

```sh
./scripts/build-app.sh
open build/macos-products/Release/Goto.app
```

Install to `~/Applications` for local development:

```sh
./scripts/install-app.sh
```

Uninstall the local app build:

```sh
./scripts/uninstall-app.sh
```

## Registry

`~/.goto` stores one absolute path per line. The CLI and `Goto.app` share it as the single source of truth.

## Scripts

| Script | Purpose |
|--------|---------|
| `install-shell.sh` | Append shell integration to `~/.zshrc` or `~/.bashrc` |
| `generate-app-icon.sh` | Generate `product/macos/Resources/Goto.icns` from `product/macos/artwork/` sources |
| `build-app.sh` | Build `Goto.app` via `xcodebuild` |
| `build-pkg.sh` | Build a single installer package containing CLI plus `Goto.app` |
| `install-app.sh` | Build `Goto.app` and install it to `~/Applications` |
| `uninstall-app.sh` | Remove `~/Applications/Goto.app` |
| `install.sh` | Install the CLI, the app, or both from the repository |
| `uninstall.sh` | Remove the packaged install from `/Applications` and `/usr/local` |
| `verify.sh` | Run the standard local verification harness; `--ci` also builds `Goto.app` |
| `package-smoke.sh` | Build or inspect a `.pkg` and verify the expected app and CLI payload |
| `typecheck-native.sh` | Type-check the Swift package without a full app build |
| `test-native.sh` | Run Swift package tests |
| `current-version.sh` | Print the current project version from `product/cli/package.json` |
| `generate_macos_project.rb` | Generate the `product/macos/Goto.xcodeproj` project |
| `notarize-pkg.sh` | Submit a built package to Apple notarization and staple it |

## Architecture

```text
goto/
  product/
    cli/                 CLI app
      bin/goto.js        CLI entry point (Node)
      src/               CLI logic: registry, picker, commands
      shell/             Shell wrappers sourced into the parent shell
      test/              Node test suite
    macos/               Xcode project for Goto.app and Finder Sync
      artwork/           Source artwork such as the SVG app icon
      Goto/              Menu bar app host and settings window
      GotoFinderSync/    Finder Sync extension toolbar button
    core/                Swift package shared by the native app and Finder extension
      Sources/
        GotoNativeCore/  Registry, terminal launch, and native helpers
      Tests/             XCTest suites for shared native logic
  scripts/               Build, install, and packaging scripts
```

The CLI and `Goto.app` share `~/.goto`. Terminal launches use AppleScript only for iTerm2; Terminal.app, Warp, Ghostty, Alacritty, and Kitty use `open -a`.

## Development

Run Node tests:

```sh
node --test product/cli/test/*.test.js
```

Run Swift tests:

```sh
./scripts/test-native.sh
```

Type-check Swift without a full build:

```sh
./scripts/typecheck-native.sh
```

Run the standard local verification harness:

```sh
./scripts/verify.sh
```

Build `Goto.app`:

```sh
./scripts/build-app.sh
```

## Documentation

- [AGENTS.md](AGENTS.md) — repository guidance and project context
- [docs/distribution-checklist.md](docs/distribution-checklist.md) — distribution packaging checklist
- [docs/github-release.md](docs/github-release.md) — GitHub Actions release flow and required secrets
- [docs/planning/ROADMAP.md](docs/planning/ROADMAP.md) — completion roadmap and verification plan
- [docs/planning/STRUCTURE.md](docs/planning/STRUCTURE.md) — current `product/` layout summary
- [docs/adr/](docs/adr/) — Architecture Decision Records
