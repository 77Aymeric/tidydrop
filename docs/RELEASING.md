# Releasing TidyDrop

TidyDrop releases are standalone Apple Silicon macOS applications. Python and the backend extractors are embedded in the app bundle with PyInstaller. Ollama and its models remain separate user-installed dependencies.

## Release Artifacts

Each release publishes:

```text
TidyDrop-<version>-macos-arm64.dmg
TidyDrop-<version>-macos-arm64.zip
SHA256SUMS.txt
```

The app is signed with Developer ID Application, hardened, notarized by Apple, and stapled before publication.

## Required GitHub Secrets

| Secret | Value |
| --- | --- |
| `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded Developer ID Application `.p12` |
| `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password chosen when exporting the `.p12` |
| `APPLE_KEYCHAIN_PASSWORD` | Random temporary CI keychain password |
| `APPLE_ID` | Apple Developer account email |
| `APPLE_TEAM_ID` | Apple Developer team identifier |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password from the Apple ID account |

Never commit these values.

## Local Packaging

Unsigned local verification:

```bash
./script/package_release.sh 0.1.0-alpha.1
```

Signed and notarized:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="TidyDrop" \
./script/package_release.sh 0.1.0-alpha.1
```

Create the local notarization profile once:

```bash
xcrun notarytool store-credentials TidyDrop \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "APP-SPECIFIC-PASSWORD"
```

## Publishing

The first public release was packaged and notarized locally, then uploaded with:

```bash
git tag -a v0.1.0-alpha.1 -m "TidyDrop v0.1.0-alpha.1"
git push origin v0.1.0-alpha.1
gh release create v0.1.0-alpha.1 \
  dist/release/TidyDrop-0.1.0-alpha.1-macos-arm64.dmg \
  dist/release/TidyDrop-0.1.0-alpha.1-macos-arm64.zip \
  dist/release/SHA256SUMS.txt
```

The Release workflow is currently opt-in and does not run when a tag is pushed. This prevents failed public release jobs until the required Apple secrets are configured in the repository.

After the secrets above are configured, start the workflow manually from GitHub Actions with a version input. It builds, signs, notarizes, verifies, tags, and publishes the release.

## Published Release

`v0.1.0-alpha.1` was published on June 14, 2026:

- [GitHub release](https://github.com/77Aymeric/tidydrop/releases/tag/v0.1.0-alpha.1)
- signed Developer ID application;
- hardened runtime enabled;
- app and DMG accepted by Apple notarization;
- stapled notarization tickets;
- Gatekeeper assessment accepted;
- DMG, ZIP, and SHA-256 checksums attached.
