# GitHub Release Flow

## Goal

Publish a single installer package from GitHub Releases.

- Artifact: `goto-<version>.pkg`
- Release trigger: push the matching Git tag (`v<version>` for version `<version>`)

## Unsigned fallback

Without a paid Apple Developer account, the workflow publishes an unsigned prerelease instead:

- artifact name: `goto-<version>-unsigned.pkg`
- GitHub release type: prerelease
- users approve the package manually in System Settings > Privacy & Security

## What the workflow does

The GitHub Actions release workflow:

1. checks out the repo
2. validates that the Git tag matches `product/cli/package.json`
3. runs JS and Swift verification
4. decides whether the release is signed or unsigned
5. builds `Goto.app` via `scripts/build-app.sh`
6. stages the CLI payload
7. builds the package
8. if notarization secrets exist, notarizes and staples the package
9. uploads the package and checksum to a GitHub Release

## Required GitHub repository secrets

If these secrets are missing, the workflow falls back to an unsigned prerelease automatically.

### Apple signing certificates

- `APPLE_DEVELOPER_ID_APP_CERT_BASE64`
- `APPLE_DEVELOPER_ID_APP_CERT_PASSWORD`
- `APPLE_DEVELOPER_ID_INSTALLER_CERT_BASE64`
- `APPLE_DEVELOPER_ID_INSTALLER_CERT_PASSWORD`
- `APPLE_DEVELOPER_ID_APPLICATION_IDENTITY`
- `APPLE_DEVELOPER_ID_INSTALLER_IDENTITY`

### Apple notarization API key

- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY_BASE64`

## Versioning rule

`product/cli/package.json` is the release source of truth.

For any GitHub release:

- package version: `<version>`
- git tag: `v<version>`
- release title: `goto <version>`

## How to cut a release

1. Commit the version change in `product/cli/package.json`
2. Push the commit to GitHub
3. Create and push the tag:

```sh
version="$(./scripts/current-version.sh --raw)"
git tag "v$version"
git push origin "v$version"
```

4. Wait for `.github/workflows/release.yml` to finish
5. Verify the GitHub Release contains either `goto-<version>.pkg` or `goto-<version>-unsigned.pkg`

## Local dry run

Build an unsigned package locally:

```sh
./scripts/build-pkg.sh
```

If your signing identities are installed locally, you can also build a signed package:

```sh
GOTO_CODESIGN_IDENTITY="Developer ID Application: ..." \
GOTO_INSTALLER_IDENTITY="Developer ID Installer: ..." \
./scripts/build-pkg.sh
```
