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

Push a version tag:

```bash
git tag v0.1.0-alpha.1
git push origin v0.1.0-alpha.1
```

The Release workflow builds, signs, notarizes, verifies, and publishes the artifacts as a prerelease.

The workflow can also be started manually from GitHub Actions with a version input.
