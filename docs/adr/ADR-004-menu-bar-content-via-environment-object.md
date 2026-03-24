# ADR-004: Menu bar content via EnvironmentObject

## Status

Accepted

## Context

`MenuBarExtra` child views did not re-render when the project list was
provided through `@ObservedObject`. The menu would appear empty on
first open and only update after the user interacted with it, creating
a visible empty-flash problem.

## Decision

Expose the project-list view model as an `@EnvironmentObject` injected
at the `MenuBarExtra` level. Load the project list at app-init time
(in the `App.init` or an `onAppear` of the top-level scene) rather
than lazily inside child views.

## Consequences

- The project list is available immediately when the menu opens; no
  empty flash on first render.
- Init-time loading adds a small startup cost, but the data source
  (a directory scan or cached file read) is fast enough to be
  imperceptible.
- All child views share a single source of truth without prop-drilling
  bindings through the menu hierarchy.
- Future views added to the menu automatically pick up the same data
  without additional wiring.
