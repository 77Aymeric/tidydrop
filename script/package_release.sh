#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.1.0-alpha.1}"
MARKETING_VERSION="${VERSION%%-*}"
APP_NAME="TidyDrop"
BUNDLE_ID="app.tidydrop.TidyDrop"
MIN_SYSTEM_VERSION="26.0"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCH="$(uname -m)"
BUILD_DIR="$ROOT_DIR/build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
BACKEND_DIST="$ROOT_DIR/build/backend"
ARTIFACT_DIR="$ROOT_DIR/dist/release"
ZIP_PATH="$ARTIFACT_DIR/$APP_NAME-$VERSION-macos-$ARCH.zip"
DMG_PATH="$ARTIFACT_DIR/$APP_NAME-$VERSION-macos-$ARCH.dmg"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

cd "$ROOT_DIR"

if [[ ! -x .venv/bin/python ]]; then
  echo "Create the development environment first with ./script/build_and_run.sh." >&2
  exit 1
fi

if ! .venv/bin/python -c "import PyInstaller" >/dev/null 2>&1; then
  .venv/bin/python -m pip install -e ".[release]"
fi

rm -rf "$BUILD_DIR" "$BACKEND_DIST" "$ARTIFACT_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES/backend" "$ARTIFACT_DIR"

swift build -c release
SWIFT_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
cp "$SWIFT_BINARY" "$APP_MACOS/$APP_NAME"
cp "$ROOT_DIR/Assets/TidyDrop.icns" "$APP_RESOURCES/TidyDrop.icns"
chmod +x "$APP_MACOS/$APP_NAME"

.venv/bin/python -m PyInstaller \
  --clean \
  --noconfirm \
  --onedir \
  --name TidyDropBackend \
  --distpath "$BACKEND_DIST" \
  --workpath "$ROOT_DIR/build/pyinstaller" \
  --specpath "$ROOT_DIR/build" \
  backend/standalone.py

cp -R "$BACKEND_DIST/TidyDropBackend" "$APP_RESOURCES/backend/"

cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>TidyDrop.icns</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 TidyDrop contributors. MIT License.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

sign_bundle() {
  local identity="$1"

  while IFS= read -r -d '' file; do
    if file "$file" | grep -q "Mach-O"; then
      codesign --force --options runtime --timestamp --sign "$identity" "$file"
    fi
  done < <(find "$APP_RESOURCES/backend" -type f -print0)

  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$identity" \
    "$APP_BUNDLE"
}

if [[ -n "$SIGN_IDENTITY" ]]; then
  sign_bundle "$SIGN_IDENTITY"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
  echo "Built with an ad hoc signature. Set SIGN_IDENTITY for public distribution."
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ -n "$NOTARY_PROFILE" ]]; then
  NOTARY_ZIP="$BUILD_DIR/$APP_NAME-notarization.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  spctl --assess --type execute --verbose=2 "$APP_BUNDLE"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

DMG_STAGE="$BUILD_DIR/dmg"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
fi

(
  cd "$ARTIFACT_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")" > SHA256SUMS.txt
)

echo
echo "Release artifacts:"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
echo "  $ARTIFACT_DIR/SHA256SUMS.txt"
