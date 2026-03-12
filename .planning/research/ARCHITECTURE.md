# `goto` Architecture Research

## Recommendation

Use a two-part architecture:

1. A thin shell wrapper loaded into `bash` and `zsh`.
2. One small chooser/registry program invoked by that wrapper.

This split is mandatory, not optional: a child process cannot change the parent shell's working directory. The wrapper owns `cd`; the chooser owns everything else.

For the smallest practical v1, the chooser should be a single Node.js entrypoint with one small prompt dependency. That keeps the install local and simple, aligns with the desired polished CLI feel, and avoids a full TUI framework.

## Smallest Practical Shape

### Runtime Choice

Recommended runtime: the host machine's current Node.js LTS.

Why this is the smallest practical option:

- Node is already available on the target machine.
- One script can handle argument parsing, registry I/O, and the TUI.
- A single prompt dependency can provide a more intentional UI than hand-rolled ANSI alone.
- The project stays easy to install from this repository with `npm install`, `npm link`, and one sourced shell file.

If the implementation later outgrows this, the wrapper/chooser contract can stay unchanged while the chooser is replaced by a compiled binary. The split is the stable part.

## Component Boundaries

### 1. Shell Wrapper Layer

Responsibility:

- Expose the user-facing `goto` command inside the current shell session.
- Decide whether the user is asking to select, add, or remove.
- Perform `cd` in the parent shell after a successful selection.
- Stay intentionally dumb: no registry parsing, no TUI logic.

Suggested files:

- `shell/goto.bash`
- `shell/goto.zsh`

These files can be tiny. Their only shell-specific work should be locating the repo root and defining the same `goto()` function.

Expected behavior:

- `goto`
  - Runs the chooser in `select` mode.
  - Captures the returned path.
  - Calls `cd -- "$path"` if a path was returned.
- `goto -a`
  - Uses `$PWD` as the target.
  - Delegates to chooser `add`.
- `goto -a PATH`
  - Delegates to chooser `add PATH`.
- `goto -r`
  - Uses `$PWD` as the target.
  - Delegates to chooser `remove`.
- `goto -r PATH`
  - Delegates to chooser `remove PATH`.

### 2. Chooser / Registry Program

Responsibility:

- Parse subcommands.
- Normalize and validate paths.
- Load and rewrite the registry dotfile.
- Run the TUI in selection mode.
- Return exactly one selected directory path on success.

Suggested file:

- `bin/goto.js`

Suggested internal subcommands:

- `select`
- `add [PATH]`
- `remove [PATH]`

The shell wrapper should be the only public interface. The chooser program is an internal implementation detail.

### 3. Registry Store

Responsibility:

- Persist the list of registered directories.
- Keep the format trivial enough to inspect and repair by hand.

Suggested location:

- `~/.goto`

Suggested format:

- One canonical absolute path per line.

Why this format is the right v1 choice:

- It is smaller than JSON and easier to edit manually.
- Project display names can be derived from `basename(path)` at runtime.
- Duplicate prevention is simple after canonicalization.

Suggested registry rules:

- Expand `~`, then resolve to an absolute canonical path.
- Store only directories that currently exist.
- Deduplicate by canonical absolute path.
- Preserve insertion order.
- Rewrite atomically with temp-file-and-rename semantics.

### 4. TUI Renderer / Input Loop

Responsibility:

- Render the list of registered directories.
- Handle up/down, Enter, and Esc.
- Present a polished but minimal terminal UI.

Important contract:

- The TUI must not use captured stdout for screen drawing.
- The shell wrapper will likely use command substitution such as `target="$(...)"`.
- Therefore the chooser should read input from `/dev/tty` and render to `/dev/tty`, while reserving stdout for the final selected path only.

This is the most important implementation detail in the whole design. Without it, the chooser UI will disappear into command substitution instead of rendering in the terminal.

## Data Flow

### Select / Jump Flow

1. User runs `goto`.
2. Shell wrapper invokes `goto.js select`.
3. Chooser opens `/dev/tty` for interactive rendering and key reads.
4. Chooser loads `~/.goto`, derives display labels, and renders the list.
5. User presses up/down to move, Enter to confirm, or Esc to cancel.
6. On Enter, chooser writes the chosen absolute path to stdout and exits `0`.
7. On Esc, chooser writes nothing to stdout and exits with a cancel code such as `130`.
8. Shell wrapper checks whether a path was returned and runs `cd` in the current shell.

### Add Flow

1. User runs `goto -a` or `goto -a PATH`.
2. Shell wrapper resolves the default argument to `$PWD` when needed.
3. Chooser canonicalizes the target path.
4. Chooser validates that the directory exists.
5. Chooser updates the dotfile atomically.
6. Chooser prints a short confirmation message and exits with status `0`.

### Remove Flow

1. User runs `goto -r` or `goto -r PATH`.
2. Shell wrapper resolves the default argument to `$PWD` when needed.
3. Chooser canonicalizes the target path.
4. Chooser removes the matching line from the dotfile if present.
5. Chooser prints a short confirmation or no-op message and exits.

## UI Direction

The UI should look intentional, but the code should stay simple.

Recommended presentation:

- Bold single-line header such as `goto`.
- Muted subtitle or help line.
- Compact list where the selected row is visibly highlighted.
- Show both project name and full path.
- Footer hint like `↑/↓ move  Enter open  Esc cancel`.

Implementation guidance:

- Use ANSI color, bold, dim, and reverse-video styles.
- Hide the cursor while the picker is active and restore it in a `finally` block.
- Redraw the full screen on each keypress; the list is small, so complexity is not justified.
- Avoid bringing in a full TUI framework for v1.

This is enough to approximate the clean, restrained feel referenced in the project brief without creating framework overhead.

## Proposed File Layout

Minimal implementation layout:

```text
shell/
  goto.bash
  goto.zsh
bin/
  goto.js
```

User-owned persisted state:

```text
~/.goto
```

Nothing else is required for a usable v1.

## Build Order

1. Define the wrapper/chooser contract.
   - `select` prints only the chosen path to stdout.
   - Interactive rendering uses `/dev/tty`.
   - `add` and `remove` own all registry writes.
2. Implement registry I/O and path normalization in `goto.js`.
   - This is the stable core logic and should exist before any UI work.
3. Implement `add` and `remove`.
   - These commands are easy to verify and prove the registry format.
4. Implement `select` with a simple full-redraw TUI.
   - Start with loading entries, moving selection, Enter, and Esc.
5. Add `bash` and `zsh` wrappers.
   - Keep them thin and identical in behavior.
6. Add polish and edge-case handling.
   - Empty registry state.
   - Missing directories.
   - Terminal cleanup on crashes or Ctrl-C.

## Rejected Heavier Options

### External finder such as `fzf`

Rejected because it adds a dependency and weakens the "local install from this repo" goal.

### Full TUI framework

Rejected because the required interaction is tiny and raw ANSI is enough.

### Compiled binary first

Rejected for v1 because it adds a build step without changing the required shell-wrapper boundary.

## Architecture Summary

The smallest architecture that actually satisfies the product is:

- a sourceable shell wrapper for `bash` and `zsh`,
- one self-contained chooser/registry program,
- one newline-delimited user dotfile registry.

The critical design rule is that the wrapper owns `cd`, while the chooser owns selection and persistence. The chooser must render through `/dev/tty` and reserve stdout for the chosen path so shell integration works cleanly.
