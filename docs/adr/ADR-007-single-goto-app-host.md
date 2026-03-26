# ADR-007: Unified `Goto.app` Host

**Status:** Accepted
**Date:** 2026-03-25

## Context

ADR-006 split the native product into `goto-menubar` and `goto-finder` to reduce duplication and allow separate installation. In practice, the packaged distribution installs both native apps together, the Finder host contains no meaningful UI of its own, and users end up managing two background apps for one feature set.

At the same time, the Finder Sync extension still requires an Xcode-built host app with an embedded `.appex`, while the menu bar UI already provides the only meaningful user-facing native settings surface.

## Decision

Collapse the native host responsibilities back into a single `Goto.app`:

1. `Goto.app` owns the menu bar UI, settings window, launch-at-login flow, and Finder bridge lifecycle.
2. `GotoFinderSync.appex` remains embedded inside `Goto.app` and continues to communicate with the host through `DistributedNotificationCenter`.
3. The CLI remains a separate install surface and still shares `~/.goto` and `~/.goto-settings` with the native app.
4. The Xcode project becomes the source of truth for the host app build, packaging, and extension embedding.

## Consequences

- Users install and manage one native app instead of two.
- Packaging simplifies from two `/Applications` bundles to one `Goto.app` bundle.
- Finder IPC architecture from ADR-001 and ADR-005 remains unchanged; only the host ownership changes.
- Legacy standalone `GotoMenuBar` code paths are removed; `Goto.app` is the only supported native host shape.
