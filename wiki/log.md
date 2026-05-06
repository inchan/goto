# Goto Wiki Log

## 2026-05-06 init | project wiki

Initialized the llm-wiki structure for durable Goto project knowledge.

## 2026-05-06 cleanup | shared project list behavior

Recorded the cleanup pass that moved CLI project list behavior onto the shared implementation and documented menu bar grouping behavior.

## 2026-05-06 refactor | deterministic project list model

Centralized sort option identifiers, next-option transitions, and ordered project output in the shared project-list model. Documented the refactor boundary in `concepts/shared-project-list-model`.

## 2026-05-06 refactor | simple output boundary

Removed the shared row enum and kept separator rows inside the CLI. Simplified CLI project layout to column widths only, while preserving ordered project output from the shared model.

## 2026-05-06 review | Claude simplicity pass

Ran an external Claude review over the uncommitted diff. Applied the clear fixes: menu bar groups now key by full parent path, settings navigation dropped a redundant always-selectable abstraction, and root app bundles are ignored.

## 2026-05-06 rename | Goto product name

Renamed the product from Goto3 to Goto across app targets, CLI target, bundle identifiers, URL schemes, Swift types, tests, docs, and install flow. The CLI data files remain `~/.goto`, `~/.goto_recent`, and `~/.goto_config` because they were already the canonical user data paths.
