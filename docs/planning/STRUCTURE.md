# Repository Structure Plan

## Current layout

The repo is already split into three practical areas:

- **CLI surface** — `product/cli/`
- **Native shared core** — `product/core/`
- **macOS app surface** — `product/macos/`

Supporting areas:

- **automation** — `scripts/`, `.github/`
- **docs** — `docs/`, `README.md`, ADRs
- **artifacts / local runtime** — `build/`, `product/core/.build/`, `.omx/`, `.claude/`

## Current structure direction

The repo now follows this boundary:

```text
product/
  cli/          # current bin + src + shell + related tests
  macos/        # Xcode host app and Finder Sync extension
    artwork/    # source artwork for the native app
  core/         # shared native Swift package

docs/
scripts/
```

## Why this direction

- `product/cli` and `product/macos` contain **user-facing execution surfaces**
- `product/core` contains **reusable internal code**
- `build/`, `product/core/.build/`, `.omx/`, and `.claude/` should stay out of the committed structure story

## Follow-up rule

Keep future moves aligned to these boundaries:

1. `product/cli` for the CLI surface
2. `product/macos` for the native app surface
3. `product/core` for reusable shared code
4. `build/`, `.build/`, `.omx/`, and `.claude/` stay out of the committed product structure
