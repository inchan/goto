# Repository Instructions

## Branch Policy

- `develop` is the primary working branch and the integration point.
- `main` is the release branch. Pushing to `main` triggers `.github/workflows/release.yml` which cuts an automatic patch release.
- Do not push work directly to `main`.

### Two-step PR flow

1. **Feature/fix work** branches off `develop` (e.g. `feat/...`, `fix/...`) and is PR'd back into `develop`. Small day-to-day commits can land on `develop` directly if the user explicitly approves.
2. **Release**: open a PR from `develop` → `main`. Merging this PR cuts the release.

Never PR a feature branch directly into `main`. Never push to `main`.

### gh CLI account

- Repo lives under user account `inchan`.
- `gh` may have multiple accounts configured; if push/PR returns 403, run `gh auth switch -u inchan` before retrying. Restore the previous account afterward if needed.

## Product Name

- The product name is `Goto`.
- Do not reintroduce `Goto3`, `goto3`, or `com.inchan.goto3` except when documenting legacy cleanup or migration behavior.
