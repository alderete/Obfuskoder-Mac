#!/bin/bash
#
# Release flow: archive → Developer ID export → notarize → staple → verify → zip.
# Output lands in dist/Obfuskoder-<tag>.zip, ready to attach to a GitHub Release.
#
# One-time setup (see docs/RELEASING.md):
#   1. A "Developer ID Application" certificate in the login keychain
#      (Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates… ▸ + ▸ Developer ID Application)
#   2. Stored notarization credentials:
#      xcrun notarytool store-credentials "Obfuskoder" \
#          --apple-id <your-apple-id> --team-id 49E99H2Q84
#      (uses an app-specific password from account.apple.com)

set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME=Obfuskoder
TEAM_ID=49E99H2Q84
NOTARY_PROFILE=Obfuskoder
VERSION=$(git describe --tags --always)
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/obfuskoder-release-XXXXXX")
ARCHIVE="$WORK_DIR/Obfuskoder.xcarchive"
EXPORT_DIR="$WORK_DIR/export"

echo "== Preflight =="
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "error: no 'Developer ID Application' certificate in the keychain." >&2
    echo "Create one in Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates… (+ ▸ Developer ID Application)." >&2
    exit 1
fi
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "error: no notarytool credential profile '$NOTARY_PROFILE'." >&2
    echo "Run: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <your-apple-id> --team-id $TEAM_ID" >&2
    echo "(Uses an app-specific password from account.apple.com.)" >&2
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "warning: working tree is not clean — archiving the current state anyway."
fi
echo "Releasing $VERSION"

echo "== Archive =="
xcodebuild archive -scheme "$SCHEME" -archivePath "$ARCHIVE" -quiet

echo "== Export (Developer ID) =="
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist Config/ExportOptions.plist \
    -exportPath "$EXPORT_DIR" -allowProvisioningUpdates -quiet

APP="$EXPORT_DIR/Obfuskoder.app"

echo "== Notarize (this waits for Apple; typically a few minutes) =="
ditto -c -k --keepParent "$APP" "$WORK_DIR/notarize.zip"
xcrun notarytool submit "$WORK_DIR/notarize.zip" \
    --keychain-profile "$NOTARY_PROFILE" --wait

echo "== Staple & verify =="
xcrun stapler staple "$APP"
spctl --assess --type execute -v "$APP"
codesign --verify --deep --strict "$APP"

mkdir -p dist
FINAL_ZIP="dist/Obfuskoder-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$FINAL_ZIP"
echo "== Done =="
echo "Notarized, stapled build: $FINAL_ZIP"
