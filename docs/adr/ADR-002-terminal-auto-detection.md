# ADR-002: Terminal auto-detection over manual configuration

## Status

Accepted

## Context

Roughly 80% of developers use a terminal other than Terminal.app
(iTerm2, Warp, Ghostty, Kitty, etc.). Requiring manual configuration
to specify the preferred terminal would add friction to first-run
setup and generate unnecessary support questions.

## Decision

Auto-detect the user's active terminal by inspecting
`NSWorkspace.shared.runningApplications` at the time of invocation,
matching against a known list of terminal bundle identifiers. If no
recognized terminal is running, fall back to Terminal.app. Users can
override the detected choice via a manual setting in UserDefaults.

## Consequences

- Zero-config experience for the common case; goto works out of the
  box with whichever terminal the user already has open.
- The known-terminal list must be maintained as new terminals appear.
- Detection depends on the terminal process being alive at invocation
  time; if the user quit their terminal moments before, the fallback
  activates.
- Manual override in UserDefaults gives power users full control
  without a dedicated config file.
