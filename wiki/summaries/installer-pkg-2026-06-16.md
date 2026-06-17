---
tags: [release, installer, cli]
---

# Installer package release

## Problem

Release DMG installation required dragging both `Goto.app` and `Goto Launcher.app` into Applications, while the `goto` CLI shipped as a separate zip and was not installed with the app.

## Decision

Use a macOS Installer package as the single installation unit. The release DMG now contains `Install Goto.pkg` instead of two app bundles. Running the package installs:

- `/Applications/Goto.app`
- `/Applications/Goto Launcher.app`
- `/usr/local/bin/goto`
- `/usr/local/bin/goto-uninstall`
- a marker-managed `goto()` shell wrapper for the active console user

The shell wrapper calls `/usr/local/bin/goto` by absolute path so it is not affected by older `~/.local/bin/goto` binaries that may still be earlier in `PATH`.

## Implementation

- `scripts/build-installer.sh` stages a package root from Release build products and creates `dist/Goto-vX.Y.Z.pkg`.
- `installer/components.plist` marks both app bundles as non-relocatable and uses `upgrade` overwrite behavior.
- `installer/scripts/preinstall` removes legacy app bundle names before install.
- `installer/scripts/postinstall` removes old/new marker blocks from common zsh/bash startup files and appends the current wrapper to the active user's shell profile.
- `scripts/uninstall.sh` removes current app/CLI installs, old app names, old user-local CLI binaries, shell marker blocks, and package receipts. `--purge` also removes user data and preferences.
- `.github/workflows/release.yml` builds the package, stages it into the DMG as `Install Goto.pkg`, and stops producing the separate CLI zip.
- DMG creation uses `create-dmg --skip-jenkins` so CI does not depend on Finder AppleEvents for icon positioning.

## Follow-up

The package is still built with the repo's existing ad-hoc signing posture. A future notarized Developer ID flow should sign the app bundles, package, and DMG before public distribution.
