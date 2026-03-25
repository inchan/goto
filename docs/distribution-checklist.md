# Distribution Checklist

## Goal

Ship the CLI plus unified `Goto.app` as a **single downloadable artifact** from GitHub Releases with the least engineering churn.

## Recommendation

Use a **single flat installer package** published on GitHub Releases:

- preferred public-release artifact: `goto-<version>.pkg`
- fallback free-account artifact: `goto-<version>-unsigned.pkg`

Why this is the best fit for the current repo:

- It satisfies the “one package” requirement better than Homebrew or three separate downloads.
- The repo already has install/build scripts for all three surfaces, so packaging them together is less disruptive than redesigning the product split.
- Apple’s notarization workflow explicitly supports **flat installer packages**, alongside ZIP and DMG artifacts.
- Homebrew is a weaker fit here because upstream formulae should not build `.app` bundles, which pushes a mixed CLI + app distribution toward casks/taps instead of one simple package.

### If we optimize for absolute fastest beta

A notarized **DMG or ZIP with `install.command`** is even easier to ship than a `.pkg`, but it is less polished and less “single package installer” in practice.

### If we don’t have a paid Apple Developer account

Use the same GitHub Release flow, but ship an **unsigned prerelease** package.

- GitHub can still host the artifact.
- The package can still install.
- Users will have to approve it manually in **Privacy & Security → Open Anyway**.
- This is acceptable for beta/testing distribution, not ideal for broad public rollout.

## Decision notes from official docs

- Apple notarization supports **signed app bundles, flat installer packages, and disk images**.
- Homebrew’s formula guidance says not to make formulae build `.app` bundles.

References:
- Apple: <https://developer.apple.com/documentation/security/customizing-the-notarization-workflow>
- Homebrew: <https://docs.brew.sh/Acceptable-Formulae>

## Current repo state

### Already in place

- The CLI and unified `Goto.app` are the install targets that matter for distribution.
- `package.json` is now the version source of truth (`0.0.1` for the first release target).
- The CLI, menu bar app, Finder app, and Xcode project now pull version information from that single source.
- The Finder shipping build now targets **Release**.
- README naming drift has been corrected to `GotoFinder` / `install-finder.sh`.
- `scripts/build-pkg.sh` now builds a single installer package containing CLI + menu bar + Finder.
- `.github/workflows/release.yml` now defines a GitHub-tag-driven release flow.
- `docs/github-release.md` documents the GitHub release path and required secrets.

### Current status

| Area | Current state | Notes |
|------|---------------|-------|
| GitHub prerelease lane | `v0.0.1` unsigned beta release has already shipped | This is the active distribution path right now |
| Apple code signing | Deferred until a paid Apple Developer Program account exists | Not required for the current unsigned beta lane |
| Apple notarization | Deferred until a paid Apple Developer Program account exists | Not required for the current unsigned beta lane |
| Local macOS tooling | Native verification requires full Xcode (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` in this environment) | Command Line Tools alone are insufficient for native build/test packaging steps |

## Recommended packaging shape

One `.pkg` installs all of the following:

1. **CLI payload**
   - Install the current repo-style tree to a stable prefix, for example:
     - `/usr/local/lib/goto/` or
     - `/opt/goto/`
   - Keep `bin/`, `shell/`, and any runtime JS files together so the existing shell wrappers still resolve paths correctly.

2. **Unified native app**
   - Install `Goto.app` into `/Applications`.
   - Bundle `GotoFinderSync.appex` inside `Goto.app/Contents/PlugIns/`.
   - Register the embedded extension in a postinstall step.

4. **Shell setup helper**
   - Install an easy command such as:
     - `/usr/local/bin/goto-install-shell`
   - That helper should call the packaged `install-shell.sh` against the installed prefix.
   - Prefer this over silently mutating dotfiles from a root installer process.

## Distribution checklist

### Phase 0 — Lock the release shape

- [x] Confirm the primary artifact is `goto-<version>.pkg` on GitHub Releases
- [x] Choose the permanent CLI install prefix (`/usr/local/lib/goto`)
- [x] Keep **Node 20+** as the v1 packaged-distribution prerequisite
- [ ] Decide whether the installer will:
  - [ ] only install assets, then ask the user to run shell setup
  - [x] or also perform shell setup automatically for the current user

**Recommendation:** keep Node 20+ as a documented prerequisite for the first packaged release. It is the lowest-effort path for this developer-focused tool.

### Phase 1 — Repo hardening before packaging

- [x] Switch Finder shipping build to **Release**
- [x] Make app versions come from one source of truth
- [x] Make CLI `--version` come from the same source of truth
- [x] Update shell installation so it targets the installed package path, not the repository path
- [x] Update README to reflect current names:
  - [x] `Goto.app`
  - [x] `scripts/install-finder.sh`
  - [x] `scripts/uninstall-finder.sh`
- [x] Document packaged-install prerequisites separately from repo-local setup

### Phase 2 — Build a staged payload

- [x] Add a release staging directory, for example `build/release-root/`
- [x] Stage CLI files into the chosen install prefix inside the staging root
- [x] Stage `Goto.app` into `/Applications`
- [x] Stage helper scripts (`goto-install-shell`, `goto-uninstall`)
- [x] Add a postinstall script that:
  - [x] registers the Finder Sync extension with `pluginkit`
  - [x] restarts Finder if needed
  - [ ] optionally opens Extensions settings
  - [x] runs shell setup automatically for the logged-in user when possible
  - [x] prints a manual shell setup fallback clearly

### Phase 3 — Deferred public-release track (signing and notarization)

- [ ] Obtain Apple Developer Program access (Deferred)
- [ ] Create / configure signing identities (Deferred):
  - [ ] **Developer ID Application**
  - [ ] **Developer ID Installer**
- [ ] Sign `Goto.app` and the embedded Finder Sync extension correctly
- [ ] Build the flat installer package
- [ ] Sign the `.pkg` with **Developer ID Installer**
- [ ] Submit the `.pkg` with `notarytool`
- [ ] Staple the notarization ticket to the `.pkg`
- [ ] Verify with Gatekeeper tooling before release

### Phase 4 — QA on clean machines

- [ ] Fresh install on a clean macOS user account
- [ ] Verify CLI shell setup on **zsh**
- [ ] Verify CLI shell setup on **bash**
- [ ] Verify `goto --version`
- [ ] Verify menu bar app launch and registry sync
- [ ] Verify Finder app launch and extension registration
- [ ] Verify Finder extension enable flow in System Settings
- [ ] Verify paths with spaces and non-ASCII characters
- [ ] Verify upgrade from an older local-repo install
- [ ] Verify upgrade/replacement from legacy `GotoHost.app` installs
- [ ] Verify uninstall story

### Phase 5 — Release automation

- [x] Add GitHub Actions release automation that performs:
  - [ ] version bump / version injection
  - [x] JS tests
  - [x] Swift tests
  - [x] native typecheck
  - [x] app builds
  - [x] payload staging
  - [x] pkg build
  - [x] notarization
  - [x] checksum generation
- [ ] Publish release notes
- [x] Attach the notarized `.pkg` and checksums to a GitHub Release

## Suggested implementation order

1. **Fix versioning + Release build mode**
2. **Fix shell integration to support an installed prefix**
3. **Fix README drift**
4. **Add staged payload builder**
5. **Add `.pkg` builder + postinstall**
6. **Add signing/notarization**
7. **Add release automation**

## Explicit recommendation

If the constraint is:

- **one downloadable thing**
- **all three surfaces together**
- **lowest overall complexity from today’s repo**

then choose:

> **Current plan: keep shipping `goto-<version>-unsigned.pkg` as a GitHub prerelease. The signed/notarized `goto-<version>.pkg` path is deferred until a paid Apple Developer Program account is available.**

That is the cleanest compromise between “one package” and “least engineering work.”
