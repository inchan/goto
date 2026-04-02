# Distribution Checklist

## Goal

Ship the CLI plus `Goto.app` as a single downloadable artifact from GitHub Releases with the least engineering churn.

## Recommendation

Use a single flat installer package published on GitHub Releases:

- preferred public-release artifact: `goto-<version>.pkg`
- fallback free-account artifact: `goto-<version>-unsigned.pkg`

## Current repo state

### Already in place

- The CLI and `Goto.app` are the install targets that matter for distribution.
- `product/cli/package.json` is the version source of truth for packaged releases.
- `scripts/build-pkg.sh` builds a single installer package containing the CLI and `Goto.app`.
- `docs/github-release.md` documents the GitHub release path and required secrets.

### Current status

| Area | Current state | Notes |
|------|---------------|-------|
| GitHub prerelease lane | Unsigned prerelease path is available when Apple signing secrets are absent | This remains the fallback distribution path |
| Apple code signing | Deferred until a paid Apple Developer Program account exists | Not required for the current unsigned beta lane |
| Apple notarization | Deferred until a paid Apple Developer Program account exists | Not required for the current unsigned beta lane |
| Local macOS tooling | Native verification requires full Xcode | Command Line Tools alone are insufficient for native packaging steps |

## Recommended packaging shape

One `.pkg` installs all of the following:

1. CLI payload under a stable prefix such as `/usr/local/lib/goto`
2. `Goto.app` in `/Applications`
3. shell setup helper commands such as `goto-install-shell` and `goto-uninstall`

## Distribution checklist

### Phase 0 — Lock the release shape

- [x] Confirm the primary artifact is `goto-<version>.pkg` on GitHub Releases
- [x] Choose the permanent CLI install prefix (`/usr/local/lib/goto`)
- [x] Keep Node 20+ as the v1 packaged-distribution prerequisite
- [ ] Decide whether the installer only installs assets or also performs shell setup automatically

### Phase 1 — Repo hardening before packaging

- [x] Make app versions come from one source of truth
- [x] Make CLI `--version` come from the same source of truth
- [x] Update shell installation so it targets the installed package path, not the repository path
- [x] Update README to reflect current names:
  - [x] `Goto.app`
  - [x] `scripts/install-app.sh`
  - [x] `scripts/uninstall-app.sh`

### Phase 2 — Build a staged payload

- [x] Add a release staging directory
- [x] Stage CLI files into the chosen install prefix inside the staging root
- [x] Stage `Goto.app` into `/Applications`
- [x] Stage helper scripts (`goto-install-shell`, `goto-uninstall`)
- [x] Add a postinstall script that:
  - [x] runs shell setup automatically for the logged-in user when possible
  - [x] prints a manual shell setup fallback clearly
  - [x] launches `Goto.app` for the logged-in user when possible

### Phase 3 — Deferred public-release track

- [ ] Obtain Apple Developer Program access
- [ ] Create or configure signing identities
- [ ] Sign `Goto.app`
- [ ] Build the flat installer package
- [ ] Sign the `.pkg`
- [ ] Submit the `.pkg` with `notarytool`
- [ ] Staple the notarization ticket to the `.pkg`

### Phase 4 — QA on clean machines

- [ ] Fresh install on a clean macOS user account
- [ ] Verify CLI shell setup on zsh
- [ ] Verify CLI shell setup on bash
- [ ] Verify `goto --version`
- [ ] Verify menu bar app launch and registry sync
- [ ] Verify upgrade from an older local-repo install
- [ ] Verify uninstall story

### Phase 5 — Release automation

- [x] Add GitHub Actions release automation for package builds
- [x] Upload the package and checksum to a GitHub Release
- [ ] Publish release notes

## Explicit recommendation

Keep shipping `goto-<version>-unsigned.pkg` as a GitHub prerelease until a paid Apple Developer Program account is available.
