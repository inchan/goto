# Repository Instructions

## Branch Policy

- `develop` is the primary working branch and the integration point.
- `main` is the release branch. Pushing to `main` triggers `.github/workflows/release.yml` which cuts an automatic patch release.
- Do not push work directly to `main`.

### Two-step PR flow

1. **Feature/fix work** branches off `develop` (e.g. `feat/...`, `fix/...`) and is PR'd back into `develop`. Small day-to-day commits can land on `develop` directly if the user explicitly approves.
2. **Release**: open a PR from `develop` → `main`. Merging this PR cuts the release.

Never PR a feature branch directly into `main`. Never push to `main`.

### main branch protection

- Direct push to `main` is blocked at the GitHub level (`Require a pull request before merging`).
- Required approving review count is `0`, so the PR author can self-merge the release PR without an external reviewer.
- `enforce_admins=false` — admin can bypass if absolutely needed; do not bypass unless the user asks.

### gh / git account

- All commits, pushes, and PRs in this repo MUST be authored as `inchan <kangsazang@gmail.com>`.
- If the currently active `gh` account is anything other than `inchan`, switch to it before any git/gh operation:
  - `previous=$(gh auth status 2>&1 | awk '/Active account: true/{getline; print $NF}')` (or capture via `gh auth status`)
  - `gh auth switch -u inchan`
  - perform commit/push/PR work
  - `gh auth switch -u <previous>` to restore — never leave the user on a different account.
- Same rule applies to `git config user.email` — verify it is `kangsazang@gmail.com` for this repo. If not, set local config: `git config user.email kangsazang@gmail.com`.

## Product Name

- The product name is `Goto`.
- Do not reintroduce `Goto3`, `goto3`, or `com.inchan.goto3` except when documenting legacy cleanup or migration behavior.
