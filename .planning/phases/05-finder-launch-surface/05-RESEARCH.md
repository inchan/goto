# Phase 5 Research: Finder Launch Surface

**Date:** 2026-03-14
**Status:** Complete

## Objective

Answer: what do we need to know before planning the Finder-triggered project launch flow?

## Key Findings

### 1. Finder launch is a different product surface from the menu bar

Finder integration has its own extension points and user expectations. It should not be treated as a minor add-on to the menu bar phase.

- Finder depends on selection-aware extension behavior.
- Validation must cover Finder-specific failure states, not only menu bar rendering.
- Keeping Finder in its own phase avoids entangling two different platform workflows.

### 2. Finder actions fit the desired "selected folder to Terminal" workflow better than a broad sync-oriented design

Apple's extension guidance distinguishes Finder actions from Finder Sync. For the requested "open the selected project in Terminal" behavior, the action model is the cleaner first fit.

- It maps directly to a user-selected folder.
- It keeps the implementation focused on handoff, not background folder monitoring.
- It leaves room to revisit richer Finder chrome later if real usage demands it.

### 3. Finder must reuse the Terminal bridge from Phase 4

If Finder invents a separate Terminal launch implementation, launch behavior will drift between surfaces.

- Reuse keeps permission handling consistent.
- Reuse reduces testing surface area.
- Reuse makes future terminal support decisions centralized.

### 4. Path handling is the main correctness trap

Finder launch is not hard because of list rendering. It is hard because selected folder URLs, missing items, spaces, and non-ASCII characters must survive the full handoff into Terminal without corruption.

- This phase needs stronger end-to-end path validation than the menu bar list itself.
- Manual smoke tests on real Finder selections are necessary.

## Source Notes

- Apple Developer Documentation: Finder Sync
  - <https://developer.apple.com/documentation/findersync>
- Apple Developer Documentation: App Extension Programming Guide
  - <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/>
- Apple Developer Documentation search results for Finder action extension keys such as `NSExtensionServiceAllowsToolbarItem`
  - <https://developer.apple.com/search/?q=NSExtensionServiceAllowsToolbarItem>

## Validation Architecture

### Recommended checks for this phase

- Trigger the Finder action on a normal project folder.
- Trigger the Finder action on a folder path containing spaces.
- Trigger the Finder action on a folder path containing non-ASCII characters.
- Confirm invalid selections fail clearly and do not leave Terminal in a broken state.

### Risks To Watch

- Choosing a Finder extension model that does not line up with the selected-folder workflow
- Re-implementing Terminal launch logic inside the Finder target
- Under-testing URL and path encoding edge cases

## Planning Implications

- Plan 1 should lock the Finder extension model and scaffold the target.
- Plan 2 should wire Finder selection into the shared launch bridge.
- Plan 3 should focus on Finder-specific smoke validation and error handling.

---

*Phase research completed: 2026-03-14*
