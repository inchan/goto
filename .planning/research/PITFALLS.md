# `goto` Pitfalls Research

## Scope

This document captures the main implementation and product pitfalls for `goto`: a minimal local-install terminal utility that registers project directories, presents a small TUI picker, and changes the caller's working directory through shell integration in `zsh` and `bash`.

The focus is on failure modes that are easy to miss in a small CLI/TUI project because the code appears simple while the shell and terminal behavior are not.

## High-Risk Pitfalls

| Pitfall | Why It Matters | Warning Signs | Prevention Strategy | Suggested Phase Coverage |
|---|---|---|---|---|
| Child process cannot change the parent shell directory | This is the core product constraint. A standalone binary can select a path, but it cannot directly `cd` the interactive shell that launched it. | Prototype "works" only inside the process, or prints a path without actually moving the shell. Team discussion drifts toward trying to solve `cd` entirely inside the binary. | Make the architecture explicit early: shell function/wrapper owns `cd`, compiled CLI owns selection and registry management. Define the CLI contract before writing the TUI. | Architecture and shell integration |
| TUI rendering contaminates captured stdout | The wrapper will likely capture command output to get the selected path. If the TUI also writes ANSI UI content to stdout, the wrapper may capture escape sequences instead of a clean path. | Wrapper receives blank output, ANSI junk, or multiple lines. `cd "$output"` fails after a seemingly successful selection. | Reserve stdout for machine-readable output only. Render the interactive UI to the controlling terminal or stderr. Define exit code and output semantics up front. | Architecture and TUI integration |
| Bash and zsh wrapper behavior diverges | `bash` and `zsh` differ in function loading, quoting behavior, arrays, and startup files. A shell integration that works in one often fails subtly in the other. | Setup instructions differ unexpectedly, one shell handles spaces correctly while the other does not, or one shell recursively calls itself. | Keep wrapper logic tiny and POSIX-lean where possible. Test interactive `bash` and `zsh` explicitly. Avoid shell-specific features unless guarded. | Shell integration and install flow |
| Wrapper accidentally recurses or shadows the real executable incorrectly | A shell function named `goto` can end up calling itself rather than the underlying executable if the delegation path is not explicit. | `goto` hangs, loops, or behaves differently depending on PATH order. `command goto` still resolves to the shell function. | Use an explicit executable path or a distinct internal binary name in the wrapper. Verify dispatch logic for both picker mode and `-a` / `-r` passthrough commands. | Shell integration |
| Terminal state is not restored after exit, panic, or Ctrl-C | Raw mode, alternate screen usage, cursor hiding, and input handling can leave the terminal unusable if cleanup is incomplete. | After exit the shell has no echo, the cursor stays hidden, line wrapping is broken, or the prompt looks corrupted. | Centralize terminal cleanup. Restore state on normal exit, error exit, and interrupt signals. Add manual verification for Enter, Esc, and Ctrl-C paths. | TUI foundation and QA |
| Arrow-key parsing is terminal-fragile | Arrow keys arrive as escape sequences, and naive parsing often breaks across terminals, tmux, SSH, or library versions. | Pressing arrow keys inserts `^[[A`, moves unpredictably, or only works in one terminal emulator. | Use a small battle-tested terminal input layer instead of hand-rolled escape parsing if possible. Keep supported keys minimal and test in common terminal setups. | TUI foundation |
| Registry path normalization is inconsistent | Add/remove operations become unreliable if paths are stored in different forms: relative, absolute, symlinked, trailing slash variants, or mixed `~` expansion behavior. | Duplicate registrations appear for the same directory. `goto -r PATH` fails unless the exact original string is used. | Normalize on write and compare using a canonical form. Expand `~`, resolve to absolute paths, clean separators, and decide how much symlink resolution to apply. | Registry design |
| Registry file format is too ad hoc | "Simple dotfile" can turn into fragile parsing if entries are split on whitespace or if display metadata is stored without escaping rules. | Paths with spaces break. Manual edits corrupt the file. One malformed line prevents the tool from loading. | Prefer a serialization format that safely handles spaces and malformed entries. If storing only paths, derive display names at runtime to keep the format simpler. Be tolerant when reading. | Registry design |
| Missing or moved directories create stale selections | Local project directories move often. A registry that assumes paths stay valid will decay quickly and make the picker feel broken. | Picker fills with dead entries, Enter produces errors, or the first-run impression is that the tool is unreliable. | Validate entries when loading or before jumping. Clearly mark missing paths, refuse to `cd` into invalid targets, and make cleanup easy. | Registry resilience and UX polish |
| Exit semantics are ambiguous | The wrapper needs to distinguish successful selection, user cancel, and actual errors. Without a clear contract, it may `cd` on cancel or swallow real failures. | Esc exits but still changes directory, or genuine errors are treated like user cancel. | Define a small exit code contract early. Example: success with selected path, cancel with no output, usage/runtime error with stderr messaging. Keep wrapper branching simple. | Architecture and shell integration |
| Non-interactive use behaves badly | Users may invoke `goto` in scripts, subshells, or environments without a real TTY. Launching a full TUI there will hang or emit control characters into logs. | CI or shell scripts hang, logs contain ANSI sequences, or `goto` fails under editor-integrated terminals. | Detect interactive TTY requirements. In non-interactive contexts, fail clearly or provide a non-TUI behavior only if intentionally supported. | CLI contract and resilience |
| Narrow terminal widths break layout | A polished UI that assumes a wide terminal can overflow, wrap badly, or hide the actual path information users need to disambiguate similar projects. | Long paths push content off-screen, selection highlight becomes unreadable, or the UI looks misaligned in split panes. | Design for narrow terminals from the start. Truncate intentionally, preserve the most useful path suffix, and avoid decorative layout that depends on width. | TUI polish |
| Unicode and ANSI styling outgrow the "minimal code" goal | Fancy glyphs and heavy styling can create alignment bugs and portability issues that consume disproportionate effort. | Visual polish work starts dominating the schedule. Glyph width bugs appear in some fonts or terminals. | Default to ASCII-safe layout and restrained color. Add ornamentation only if it survives width and compatibility tests. Honor `NO_COLOR` if color is used. | TUI polish |
| Install flow is correct once, but not durable | Local install from the repo is part of the product. A setup that requires manual shell edits can appear successful while failing in new terminals. | It works in the current session only. A fresh shell cannot run `goto`, or can run it but cannot change directories. | Provide explicit setup instructions for both shells, define the snippet users must source, and include a quick verification step that works in a fresh session. | Install and onboarding |
| Remove/add behavior is surprising at the current working directory | `goto -a` and `goto -r` without a PATH implicitly operate on the current directory. That is convenient, but easy to misread or misuse. | Users accidentally remove the wrong project, or are unsure whether the default target is `$PWD` or the selected entry. | Document the default-target behavior clearly and echo concise confirmation messages. Consider a safe message for no-op removals. | CLI UX |
| Concurrent writes or interrupted writes corrupt the registry | Even a single-user dotfile can be written by multiple terminals or interrupted mid-write, leaving partial content behind. | Registry sometimes empties, duplicates appear after rapid edits, or the file contains truncated JSON/text. | Write atomically via temp file + rename. Keep writes small and deterministic. Read defensively if the file is malformed. | Registry resilience |

## Key Warning Pattern

The biggest implementation trap is treating `goto` like a normal CLI app. It is not. The product boundary includes:

- A compiled executable or script that manages registry state and interactive selection
- A shell wrapper that performs the actual `cd`
- An install/setup path that makes the wrapper available in future `bash` and `zsh` sessions

If those pieces are designed separately instead of as one contract, the project will likely "almost work" for a long time.

## Recommended Prevention Priorities

1. Lock the shell integration contract before building visual polish.
2. Define stdout, stderr, and exit-code behavior before wiring the wrapper.
3. Normalize registry paths before implementing add/remove UX.
4. Make terminal cleanup robust before spending effort on styling.
5. Test in real interactive `bash` and `zsh` sessions, not just one current shell.

## Suggested Phase Coverage

| Phase Area | Pitfalls To Cover |
|---|---|
| Architecture contract | Parent-shell `cd`, stdout contamination, exit semantics, non-interactive behavior |
| Shell integration | Bash/zsh divergence, wrapper recursion, install durability |
| Registry layer | Path normalization, file format safety, stale paths, atomic writes |
| TUI foundation | Raw mode cleanup, arrow-key handling, terminal width constraints |
| UX polish and release hardening | ASCII-safe styling, `NO_COLOR`, default add/remove behavior, fresh-shell verification |

## Release Gate Checklist

Before considering v1 done, verify all of the following manually:

- `goto` changes the current directory of the interactive shell in both `bash` and `zsh`
- `goto` cancel path does not change directories
- `goto -a` and `goto -r` behave correctly with spaces in paths
- The registry survives a fresh shell session
- Dead paths do not produce a confusing or destructive jump
- Esc, Enter, and Ctrl-C all restore the terminal cleanly
- Narrow terminal widths still show a usable project list
