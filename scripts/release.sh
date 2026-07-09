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
trap 'rm -rf "$WORK_DIR"' EXIT      # clean up the temp archive/export on any exit
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

echo "== Sign update & append appcast entry =="
NOTES_FILE="${1:-}"
SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*/artifacts/sparkle/Sparkle/bin' 2>/dev/null | head -1)"
if [ -z "$SPARKLE_BIN" ] || [ ! -x "$SPARKLE_BIN/sign_update" ]; then
    echo "error: Sparkle 'sign_update' not found. Build the app once in Xcode to resolve the Sparkle package, then re-run." >&2
    exit 1
fi

# sign_update prints e.g.: sparkle:edSignature="…" length="12345"
SIG_ATTRS="$("$SPARKLE_BIN/sign_update" "$FINAL_ZIP")"
BUILD_NUMBER="$(git rev-list --count HEAD)"
DL_URL="https://github.com/alderete/Obfuskoder-Mac/releases/download/$VERSION/Obfuskoder-$VERSION.zip"
PUB_DATE="$(date -R 2>/dev/null || date '+%a, %d %b %Y %H:%M:%S %z')"

# Release notes: embed the notes file (wrapped for readable rendering in
# Sparkle's WebView) if given, else link to the GitHub release page.
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
    NOTES_HTML="<pre style=\"white-space:pre-wrap;font:13px -apple-system,sans-serif\">$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$NOTES_FILE")</pre>"
else
    NOTES_HTML="<p>See the <a href=\"https://github.com/alderete/Obfuskoder-Mac/releases/tag/$VERSION\">release notes on GitHub</a>.</p>"
fi

APPCAST="updates/obfuskoder/appcast.xml"
ITEM_FILE="$(mktemp)"
cat > "$ITEM_FILE" <<ITEM
		<item>
			<title>Obfuskoder $VERSION</title>
			<pubDate>$PUB_DATE</pubDate>
			<sparkle:version>$BUILD_NUMBER</sparkle:version>
			<sparkle:shortVersionString>1.0</sparkle:shortVersionString>
			<sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
			<description><![CDATA[$NOTES_HTML]]></description>
			<enclosure url="$DL_URL" $SIG_ATTRS type="application/octet-stream"/>
		</item>
ITEM

# Insert the new item immediately after the ITEMS marker (newest first).
awk '/<!-- ITEMS/{print; while((getline line < "'"$ITEM_FILE"'")>0) print line; close("'"$ITEM_FILE"'"); next} {print}' "$APPCAST" > "$APPCAST.tmp" && mv "$APPCAST.tmp" "$APPCAST"
rm -f "$ITEM_FILE"

xmllint --noout "$APPCAST" && echo "appcast is well-formed: $APPCAST"
echo ""
echo "ACTION REQUIRED: upload $APPCAST to https://updates.aldosoft.com/obfuskoder/appcast.xml"

echo "== Done =="
echo "Notarized, stapled build: $FINAL_ZIP"
