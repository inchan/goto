# Goto Wiki Schema

## Domain Scope

This wiki covers durable project knowledge for Goto: architecture, CLI behavior, menu bar behavior, settings persistence, testing expectations, and cleanup notes.

Out of scope: external macOS API references copied verbatim, temporary build logs, local machine state, and release artifacts.

## Directory Categories

- `summaries/`: concise summaries of implementation changes and maintenance passes.
- `concepts/`: stable explanations of product behavior, architecture decisions, and shared implementation patterns.
- `entities/`: named code modules, targets, or external tools when they need their own page.
- `comparisons/`: side-by-side tradeoff notes.
- `raw/`: immutable source notes when a source needs preservation.
- `audit/`: review findings or human feedback that has not been folded into stable pages.

## Tags

Allowed tags:

- `architecture`
- `cli`
- `cleanup`
- `docs`
- `menubar`
- `refactor`
- `settings`
- `testing`
- `worktree`

New tags require updating this file first.

## Naming

Use lowercase kebab-case file names. Page titles should be short, human-readable headings. Internal links use wikilink syntax without the `.md` suffix.

## Page Thresholds

Target 200-800 words per page for this small codebase. Split pages that grow past 1000 words. Every compiled page should include frontmatter with `title`, `date`, and `tags`.

## Open Questions

- Should menu bar grouping also share the exact CLI project row model, or stay menu-specific because submenu behavior is AppKit-only?
- Should the old root-level roadmap return later as wiki pages under `audit/`, or remain removed until there is an active validation plan?
