# Phase 5: Finder Launch Surface - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning
**Source:** User goal synthesis plus targeted platform research

<domain>
## Phase Boundary

Phase 5 adds a Finder-triggered `goto` surface so a user can select a folder in Finder and open Terminal directly at that location.

This phase does not expand the registry model or add alternate terminal support. It should reuse the native launch bridge already established in Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Finder Strategy
- Treat Finder as a separate surface with its own extension target and validation path.
- Prefer a Finder action flow tied to the current selection before investing in a more opinionated persistent Finder toolbar experience.

### Selection Model
- Operate on the folder currently selected in Finder.
- Validate that the selected item resolves to a real directory before launching Terminal.

### Launch Reuse
- Reuse the exact Terminal handoff behavior built in Phase 4.
- Keep Finder focused on passing a validated folder URL into that launch path.

### Scope Control
- The Finder action does not need to mutate the registry in the first cut.
- Multi-select behavior, smart defaults for ambiguous selections, and background sync are all deferred.

</decisions>

<specifics>
## Specific Ideas

- Expected native additions for this phase:
  - one Finder-oriented extension or action target
  - a small adapter layer that converts Finder selection into the shared launch request
- Phase validation should include:
  - selected folder exists
  - selected item is not a file
  - paths with spaces work
  - paths with non-ASCII characters work
- Finder-specific error copy should explain the selection problem instead of failing silently.

</specifics>

<deferred>
## Deferred Ideas

- Registering the selected Finder folder into `~/.goto`
- Alternate terminals
- Multi-select launch behavior
- Finder Sync-specific monitored-folder features beyond the basic launch action

</deferred>

---

*Phase: 05-finder-launch-surface*
*Context gathered: 2026-03-14 from user goals and macOS platform constraints*
