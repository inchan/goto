# GitHub Release Flow

## Goal

Publish a single notarized installer package from GitHub Releases.

- Artifact: `goto-<version>.pkg`
- Initial release target: `0.0.1`
- Release trigger: push the matching Git tag (`v0.0.1` for version `0.0.1`)

## If you don’t have a paid Apple Developer account

You can still use **GitHub Releases**.

What you **can’t** do without the paid Apple Developer Program is:

- issue **Developer ID** certificates
- **notarize** the package with Apple

So the practical fallback is:

- publish an **unsigned prerelease** from GitHub
- artifact name becomes `goto-<version>-unsigned.pkg`
- users install it manually and approve it in **System Settings → Privacy & Security → Open Anyway**

This is fine for early testers, internal distribution, and pre-release validation.
It is **not** ideal for broad public distribution.

**Current decision:** stay on the unsigned GitHub prerelease lane for now, and defer the signed/notarized lane until the paid Apple account exists.

## What the workflow does

The GitHub Actions release workflow:

1. checks out the repo
2. validates that the Git tag matches `package.json`
3. runs JS + Swift verification
4. decides whether the release is **signed** or **unsigned**
5. if signing secrets exist, imports Apple signing certificates
6. builds `Goto.app` via `scripts/build-app.sh`
7. stages the embedded Finder Sync extension inside `Goto.app`
8. stages the CLI payload
9. builds the package
10. if notarization secrets exist, notarizes and staples the package
11. uploads the package and checksum to a GitHub Release

## Required GitHub repository secrets

If these secrets are **missing**, the workflow falls back to an **unsigned prerelease** automatically.
That fallback is now the intended short-term plan.

### Apple signing certificates

- `APPLE_DEVELOPER_ID_APP_CERT_BASE64`
  - Base64-encoded `.p12` containing the **Developer ID Application** certificate
- `APPLE_DEVELOPER_ID_APP_CERT_PASSWORD`
  - Password for that `.p12`
- `APPLE_DEVELOPER_ID_INSTALLER_CERT_BASE64`
  - Base64-encoded `.p12` containing the **Developer ID Installer** certificate
- `APPLE_DEVELOPER_ID_INSTALLER_CERT_PASSWORD`
  - Password for that `.p12`
- `APPLE_DEVELOPER_ID_APPLICATION_IDENTITY`
  - Exact identity name for codesigning apps
- `APPLE_DEVELOPER_ID_INSTALLER_IDENTITY`
  - Exact identity name for signing the installer package

### Apple notarization API key

- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY_BASE64`
  - Base64-encoded App Store Connect API private key (`.p8`)

## Versioning rule

`package.json` is the release source of truth.

For the first GitHub release:

- package version: `0.0.1`
- git tag: `v0.0.1`
- release title: `goto 0.0.1`

If Apple signing/notarization secrets are missing, the release becomes:

- artifact: `goto-0.0.1-unsigned.pkg`
- release title: `goto 0.0.1 (unsigned beta)`
- GitHub release type: **prerelease**

## How to cut a release

1. Commit the version change in `package.json`
2. Push the commit to GitHub
3. Create and push the tag:

```sh
git tag v0.0.1
git push origin v0.0.1
```

4. Wait for `.github/workflows/release.yml` to finish
5. Verify the GitHub Release contains:
   - either `goto-0.0.1.pkg` or `goto-0.0.1-unsigned.pkg`
   - the matching `.sha256` file

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

Then notarize it:

```sh
APPLE_API_KEY_ID="..." \
APPLE_API_ISSUER_ID="..." \
APPLE_API_PRIVATE_KEY_PATH="/path/to/AuthKey_XXXX.p8" \
./scripts/notarize-pkg.sh build/goto-0.0.1.pkg
```

## User-facing note for unsigned releases

For unsigned beta releases, users should expect a Gatekeeper warning on first open/install.
Apple’s official guidance is that they can approve a trusted app or installer via:

1. attempting to open/install it first
2. going to **System Settings**
3. opening **Privacy & Security**
4. clicking **Open Anyway**

## References

- Apple Support — Safely open apps on your Mac: <https://support.apple.com/en-us/102445>
- GitHub Actions secrets: <https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets>
- Apple notarization: <https://developer.apple.com/documentation/security/customizing-the-notarization-workflow>
