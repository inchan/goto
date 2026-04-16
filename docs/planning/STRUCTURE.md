# Repository Structure Plan

## Current layout

The repo is split into three practical areas:

- **CLI surface** — `product/cli/`
- **Native shared core** — `product/core/`
- **macOS app surface** — `product/macos/`

Supporting areas:

- **automation** — `scripts/`, `.github/`
- **docs** — `docs/`, `README.md`, ADRs
- **artifacts / local runtime** — `build/`, `product/core/.build/`, `.omx/`, `.claude/`

## Current structure direction

```text
product/
  cli/          # current bin + src + shell + related tests
  macos/        # Xcode app targets and resources
    Goto/       # menu bar app host and settings window
    GotoFinderSync/ # Finder toolbar extension
    artwork/    # source artwork for the native app
    Resources/  # app resources such as the icon
  core/         # shared native Swift package for app + Finder extension

docs/
scripts/
```

## Why this direction

- `product/cli` and `product/macos` contain user-facing execution surfaces
- `product/core` contains reusable internal code
- build outputs and local runtime state stay out of the committed structure story
