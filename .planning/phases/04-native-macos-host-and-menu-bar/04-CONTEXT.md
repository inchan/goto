# Phase 4: Native macOS Host And Menu Bar - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning
**Source:** User goal synthesis plus targeted platform research

<domain>
## Phase Boundary

Phase 4 adds the first native macOS surface on top of the existing shell-first `goto` core. The deliverable is a native host app with a menu bar entry point that reads the saved projects registry, shows project state, and opens the chosen project in Terminal.

This phase does not include Finder-triggered launch. Finder is a separate surface with different extension mechanics and should stay in Phase 5.

</domain>

<decisions>
## Implementation Decisions

### Native Host
- Use a native macOS host app rather than trying to fake menu bar behavior from Node.
- Prefer SwiftUI with `MenuBarExtra` for the menu bar entry point.

### Shared Data Contract
- Keep `~/.goto` as the single registry file shared across shell and native surfaces.
- Match the existing CLI semantics closely: stable ordering, missing-path visibility, and absolute path handling.

### Terminal Handoff
- Target Terminal.app first.
- The native launch path should either reuse the active Terminal context when possible or create a Terminal session if none exists.
- Treat Terminal automation approval as a first-class validation concern, not an afterthought.

### Surface Scope
- Phase 4 is read-and-launch, not full registry management.
- Add/remove flows remain owned by the existing CLI until native launch is proven stable.

</decisions>

<specifics>
## Specific Ideas

- Expected native structure for this phase:
  - `macos/` for the Xcode project or workspace
  - one app target for the menu bar host
  - one shared native module for registry reading and launch handoff
- The menu bar list should show:
  - project name
  - full path or a truncated path subtitle
  - a visible missing/disabled state for broken entries
- The launch bridge should be reusable by later Finder work so Finder does not invent a second Terminal control path.

</specifics>

<deferred>
## Deferred Ideas

- Finder actions and Finder-specific UI
- Alternate terminals such as iTerm or WezTerm
- Native add/remove management inside the menu bar
- Search, favorites, aliases, and any registry metadata beyond saved paths

</deferred>

---

*Phase: 04-native-macos-host-and-menu-bar*
*Context gathered: 2026-03-14 from user goals and macOS platform constraints*
