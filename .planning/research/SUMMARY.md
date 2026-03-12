# Project Research Summary

**Project:** goto
**Domain:** local shell-integrated CLI/TUI productivity tool
**Researched:** 2026-03-12
**Confidence:** HIGH

## Executive Summary

`goto` is not a normal standalone CLI. It is a small shell-integrated developer utility whose real product boundary spans three parts: a sourced `zsh`/`bash` wrapper, a chooser/registry program, and a local registry file. Research across stack, feature, architecture, and pitfalls consistently shows that the hard part is not drawing a list in the terminal. The hard part is making parent-shell `cd`, TUI rendering, and registry behavior work together cleanly.

The recommended approach is a buildless Node.js CLI with a very small dependency surface and thin shell wrappers. This best matches the desired polished terminal feel, the user's `skills.sh`-style UI reference, and the existing local environment, while still keeping the code footprint small. The roadmap should sequence the contract first, then registry mutations, then the picker, and only then UI polish and installation hardening.

The main risks are architectural rather than feature-related: contaminating captured stdout with TUI output, letting `bash` and `zsh` wrappers drift, and under-specifying cancel/error behavior. If those are designed explicitly from the start, the rest of the project is straightforward.

## Key Findings

### Recommended Stack

The strongest stack recommendation is a minimal Node.js implementation with one prompt dependency plus two tiny sourced shell wrappers. The deciding factors are: the machine already has `node v24.14.0` and `npm 11.9.0`, the project wants a polished terminal feel rather than a raw ANSI prototype, and the scope is local install rather than broad package distribution.

**Core technologies:**
- Node.js CLI: argument parsing, filesystem access, registry mutations, and command dispatch in one small runtime
- `@clack/prompts`: polished terminal selection UI without adopting a heavyweight TUI framework
- `zsh` and `bash` wrapper functions: perform parent-shell `cd` after the chooser returns a selected path
- `~/.goto`: newline-delimited registry of canonical absolute paths

### Expected Features

Research strongly separates true table stakes from tempting extras. A credible v1 needs shell integration, add/remove commands, a reliable keyboard-driven picker, durable local storage, and sensible handling of duplicate or dead paths. The most valuable differentiators are polish-oriented rather than feature-oriented: clear name/path hierarchy, restrained copy, predictable ordering, and strong empty-state behavior.

**Must have (table stakes):**
- Run `goto` and pick a saved project with up/down, Enter, and Esc
- Add and remove projects via `goto -a`, `goto -a PATH`, `goto -r`, and `goto -r PATH`
- Change the current directory in the interactive parent shell for both `zsh` and `bash`
- Persist projects locally and prevent duplicate registrations
- Show both project name and full path

**Should have (competitive):**
- Clean visual hierarchy in the picker
- Clear first-run and empty-state guidance
- Canonical path normalization
- Stable ordering that supports muscle memory

**Defer (v2+):**
- Fuzzy search and live filtering
- Tags, groups, favorites, or metadata
- Sync or shared registries
- Shell support beyond `zsh` and `bash`
- Publish/distribution work beyond local install

### Architecture Approach

The architecture should be a strict two-part split: thin shell wrappers own `cd`, while the Node chooser program owns registry I/O, selection, and terminal interaction. The chooser must render interactively to the controlling terminal while reserving `stdout` for the selected path only; otherwise command substitution in the shell wrapper will break.

**Major components:**
1. Shell wrapper layer: defines `goto` in `zsh` and `bash`, delegates subcommands, and runs `cd`
2. Chooser/registry program: implements `select`, `add`, and `remove`, and owns path normalization plus exit semantics
3. Registry store: newline-delimited canonical paths in `~/.goto`

### Critical Pitfalls

1. **Trying to `cd` from the child process** — avoid by locking the wrapper/chooser contract before writing UI code
2. **Mixing TUI output with captured stdout** — avoid by reserving stdout for the final path and rendering UI elsewhere
3. **Wrapper drift between `bash` and `zsh`** — avoid by keeping wrappers tiny and behaviorally identical
4. **Weak path normalization** — avoid by canonicalizing on write and comparing normalized paths on remove
5. **Broken terminal cleanup** — avoid by restoring cursor/state on Enter, Esc, error, and Ctrl-C paths

## Implications for Roadmap

Based on research, the project should be built in three coarse phases.

### Phase 1: Contract And Registry Core
**Rationale:** Everything depends on the shell/chooser contract and trustworthy registry behavior.
**Delivers:** executable command contract, path normalization, atomic registry writes, `add` and `remove` flows
**Addresses:** shell integration, local storage, duplicate prevention
**Avoids:** parent-shell `cd` confusion, malformed registry, no-op remove ambiguity

### Phase 2: Picker And Jump Flow
**Rationale:** Once the registry is trustworthy, the main `goto` interaction can be built on stable ground.
**Delivers:** project picker, selection output contract, cancel behavior, missing-path handling, name/path display
**Uses:** prompt UI dependency, terminal output separation, wrapper integration
**Implements:** chooser UI and jump flow

### Phase 3: Install And Polish
**Rationale:** The tool only feels complete when a fresh shell session can use it reliably and the UI is clean.
**Delivers:** setup instructions, sourced wrapper files, visual polish, empty-state copy, release hardening
**Uses:** final shell snippets and manual validation in both shells
**Implements:** install durability and user-facing refinement

### Phase Ordering Rationale

- The shell boundary is the highest-risk constraint, so it has to be designed before UI polish.
- Registry correctness is cheaper to validate early than after the TUI exists.
- The picker should depend on a stable output contract, not invent it.
- Install hardening belongs last because it verifies the complete end-to-end flow.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** verify the exact prompt API and output-channel behavior for the chosen UI dependency
- **Phase 3:** verify shell startup-file guidance so install steps are correct for both `bash` and `zsh`

Phases with standard patterns:
- **Phase 1:** registry file handling and path normalization are well-understood and low novelty

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Supported by local environment, user UI preference, and low-scope project needs |
| Features | HIGH | User requirements are concrete and map cleanly to v1 table stakes |
| Architecture | HIGH | Parent-shell `cd` constraint makes the wrapper/chooser split non-negotiable |
| Pitfalls | HIGH | Failure modes are specific and directly tied to shell/TUI interaction |

**Overall confidence:** HIGH

### Gaps to Address

- Exact output strategy for the UI dependency should be validated in implementation
- The install flow should be verified in fresh `bash` and `zsh` sessions, not only the current shell
- Registry format migration is intentionally deferred because v1 does not need aliases or metadata yet

## Sources

### Primary
- [STACK.md](/Users/inchan/workspace/goto/.planning/research/STACK.md)
- [FEATURES.md](/Users/inchan/workspace/goto/.planning/research/FEATURES.md)
- [ARCHITECTURE.md](/Users/inchan/workspace/goto/.planning/research/ARCHITECTURE.md)
- [PITFALLS.md](/Users/inchan/workspace/goto/.planning/research/PITFALLS.md)
- Local environment inspection on 2026-03-12: `node v24.14.0`, `npm 11.9.0`, `python 3.14.3`

---
*Research completed: 2026-03-12*
*Ready for roadmap: yes*
