# ADR-006: Three-Package Split (goto, goto-menubar, goto-finder)

**Status:** Superseded by ADR-007
**Date:** 2026-03-24

## Context

The original architecture shipped CLI, menu bar, and Finder as a monolithic build
with `GotoHost.app` bundling both the menu bar UI and the Finder Sync bridge.
This caused:

- Code duplication between `native/` (SPM MenuBar) and `macos/` (Xcode GotoHost)
- A single app carrying two unrelated responsibilities (menu bar UI + Finder IPC)
- No way to install surfaces independently

## Decision

Split into three independently installable packages:

| Package | Type | Build |
|---------|------|-------|
| `goto` | CLI | Node.js (`bin/goto.js`) |
| `goto-menubar` | Menu bar app | SPM (`scripts/build-menu-bar-app.sh`) |
| `goto-finder` | Headless agent + Finder Sync extension | Xcode (`scripts/build-finder.sh`) |

### Key design choices

1. **`goto-finder` is headless** (`LSUIElement = true`, no menu bar icon).
   It only runs the `FinderLaunchBridge` for IPC with the sandboxed extension.

2. **No direct IPC between packages.** They share only two files:
   - `~/.goto` (project registry)
   - `~/.goto-settings` (Finder preferences JSON)

3. **Settings flow:** `goto-menubar` writes `~/.goto-settings`.
   `goto-finder` watches the file via `RegistryWatcher` and re-broadcasts
   to the Finder Sync extension.

4. **URL scheme changed** from `goto-host://` to `goto-finder://`.

5. **Bundle IDs changed:**
   - `dev.goto.host` → `dev.goto.finder`
   - `dev.goto.host.findersync` → `dev.goto.finder.findersync`

## Consequences

- Users can install any combination (CLI only, CLI + menu bar, full suite)
- `macos/GotoHost/` directory eliminated — no more MenuBarViewModel duplication
- Finder settings management moved to `goto-menubar`'s SettingsWindow
- Existing `GotoHost.app` installations must be replaced with `GotoFinder.app`
  and re-enabled in System Settings → Extensions
