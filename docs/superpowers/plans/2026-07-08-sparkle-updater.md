# Sparkle Software Updater Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add in-app software update checking via Sparkle 2.9.4 — automatic background checks (default monthly, user-configurable) with an ask-to-install flow and a Check for Updates… menu item.

**Architecture:** Pure `UpdateFrequency` logic lives in `ObfuskoderKit` (unit-tested, Sparkle-free); a single `SoftwareUpdater` class in the app target wraps Sparkle's `SPUStandardUpdaterController`; SwiftUI surfaces it through a menu command and a Settings section. Sandboxed Sparkle requires migrating from build-setting entitlements to an explicit `.entitlements` file. The release script signs each build and appends to a repo-tracked appcast.

**Tech Stack:** Swift 6.2, SwiftUI, Sparkle 2.9.4 (SPM), Swift Testing, macOS 14+, Developer ID + notarization.

## Global Constraints

- Swift 6.2. `ObfuskoderKit` is Swift 6 nonisolated-default; the app target is `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- Deployment target macOS 14.0.
- Sparkle version rule: `upToNextMajorVersion` from 2.9.4 (already set).
- App bundle identifier: `com.aldosoft.Obfuskoder`.
- Feed URL (verbatim): `https://updates.aldosoft.com/obfuskoder/appcast.xml`.
- Sparkle version comparison uses `CFBundleVersion` (git commit count, monotonic), NOT `CFBundleShortVersionString` (which is `"1.0"` for every beta).
- Default cadence: **monthly**. Cadence options: Daily / Weekly / Monthly / Never.
- Single feed, no channels. Downloads served from public GitHub Releases; appcast uploaded manually.
- UI strings use `String(localized:)` in `Obfuskoder/Strings.swift` (`enum UIStrings`).
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

### Task 1: Commit the Sparkle SPM package and confirm it resolves

The package was already added to `Obfuskoder.xcodeproj/project.pbxproj` (uncommitted). Lock it in and prove it builds before writing any code against it.

**Files:**
- Modify (commit only): `Obfuskoder.xcodeproj/project.pbxproj`
- Commit: `Obfuskoder.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- [ ] **Step 1: Confirm the package resolves and the app builds**

Run: `xcodebuild -scheme Obfuskoder -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **` (Sparkle 2.9.4 resolves).

- [ ] **Step 2: Commit the package addition**

```bash
git add "Obfuskoder.xcodeproj/project.pbxproj" \
        "Obfuskoder.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
git commit -m "Add Sparkle 2.9.4 via SPM to the app target

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `UpdateFrequency` enum + default (ObfuskoderKit, TDD)

The one piece of pure logic — the cadence → Sparkle-settings mapping — lives in the Kit and is fully unit-tested.

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/UpdateFrequency.swift`
- Modify: `ObfuskoderKit/Sources/ObfuskoderKit/AppConfig.swift` (add `defaultUpdateFrequency`)
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/UpdateFrequencyTests.swift`

**Interfaces:**
- Produces:
  - `public enum UpdateFrequency: String, CaseIterable, Sendable { case daily, weekly, monthly, never }`
  - `public var automaticallyChecks: Bool` (false only for `.never`)
  - `public var checkInterval: TimeInterval?` (nil for `.never`)
  - `public static let AppConfig.defaultUpdateFrequency: UpdateFrequency` (== `.monthly`)

- [ ] **Step 1: Write the failing tests**

Create `ObfuskoderKit/Tests/ObfuskoderKitTests/UpdateFrequencyTests.swift`:

```swift
import Testing
import Foundation
import ObfuskoderKit

@Test func neverDisablesAutomaticChecks() {
    #expect(UpdateFrequency.never.automaticallyChecks == false)
    #expect(UpdateFrequency.never.checkInterval == nil)
}

@Test func cadencesEnableChecksWithExpectedIntervals() {
    #expect(UpdateFrequency.daily.automaticallyChecks == true)
    #expect(UpdateFrequency.daily.checkInterval == 86_400)
    #expect(UpdateFrequency.weekly.checkInterval == 604_800)
    #expect(UpdateFrequency.monthly.checkInterval == 2_592_000)
}

@Test func defaultCadenceIsMonthly() {
    #expect(AppConfig.defaultUpdateFrequency == .monthly)
}

// @AppStorage persists the rawValue; guard against accidental renames that
// would silently reset every user's saved cadence.
@Test func rawValuesAreStableForPersistence() {
    #expect(UpdateFrequency.monthly.rawValue == "monthly")
    #expect(UpdateFrequency(rawValue: "weekly") == .weekly)
    #expect(UpdateFrequency.allCases.count == 4)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ObfuskoderKit && swift test --filter UpdateFrequency 2>&1 | tail -20`
Expected: FAIL — `cannot find 'UpdateFrequency' in scope` / `defaultUpdateFrequency`.

- [ ] **Step 3: Implement `UpdateFrequency`**

Create `ObfuskoderKit/Sources/ObfuskoderKit/UpdateFrequency.swift`:

```swift
import Foundation

/// User-facing cadence for automatic update checks. A pure mapping to Sparkle's
/// two knobs (`automaticallyChecksForUpdates` + `updateCheckInterval`), kept in
/// the Kit so it is unit-testable with no Sparkle/WebKit dependency — the same
/// pattern as `PreviewNavigationPolicy`. Backed by `String` so it persists via
/// `@AppStorage`.
public enum UpdateFrequency: String, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case never

    /// Whether Sparkle should check automatically. `.never` turns checks off.
    public var automaticallyChecks: Bool { self != .never }

    /// The check interval in seconds, or nil when checks are disabled.
    public var checkInterval: TimeInterval? {
        switch self {
        case .daily:   return 86_400
        case .weekly:  return 604_800
        case .monthly: return 2_592_000   // 30 days
        case .never:   return nil
        }
    }
}
```

- [ ] **Step 4: Add the default to `AppConfig`**

In `ObfuskoderKit/Sources/ObfuskoderKit/AppConfig.swift`, add inside `public enum AppConfig`:

```swift
    /// Default automatic-update cadence (SPEC: Sparkle updater).
    public static let defaultUpdateFrequency: UpdateFrequency = .monthly
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd ObfuskoderKit && swift test --filter UpdateFrequency 2>&1 | tail -20`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/UpdateFrequency.swift \
        ObfuskoderKit/Sources/ObfuskoderKit/AppConfig.swift \
        ObfuskoderKit/Tests/ObfuskoderKitTests/UpdateFrequencyTests.swift
git commit -m "Add UpdateFrequency cadence mapping (Kit, tested)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Entitlements migration + Info.plist keys + EdDSA key

The delicate one. Migrate from build-setting entitlements to an explicit file (required for Sparkle's mach-lookup exception), add the Sparkle Info.plist keys, and generate the signing key. Gate on a `codesign` diff — this must preserve sandbox/network/file access exactly.

**Files:**
- Create: `Obfuskoder/Obfuskoder.entitlements`
- Modify: `Obfuskoder.xcodeproj/project.pbxproj` (both app-target build blocks near lines 412 and 443)
- Modify: `Config/Info.plist`

- [ ] **Step 1: Record the current shipped entitlements (baseline)**

Run: `xcodebuild -scheme Obfuskoder -configuration Debug build 2>&1 | tail -2 && APP="$(xcodebuild -scheme Obfuskoder -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/{print $3; exit}')/Obfuskoder.app" && codesign -d --entitlements - "$APP" 2>/dev/null`
Expected: shows `app-sandbox`, `files.user-selected.read-write`, `network.client` = true. Note this set — the migration must reproduce it plus the new mach-lookup key.

- [ ] **Step 2: Create the entitlements file**

Create `Obfuskoder/Obfuskoder.entitlements` (the `Obfuskoder/` folder is a file-system-synchronized group, so the file is picked up automatically; `.entitlements` is not compiled):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
	<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
	<array>
		<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
	</array>
</dict>
</plist>
```

(No `-spks`: the Downloader XPC service is unused because the app has `network.client`. Xcode substitutes `$(PRODUCT_BUNDLE_IDENTIFIER)` → `com.aldosoft.Obfuskoder` at signing time.)

- [ ] **Step 3: Point the target at the entitlements file and drop the redundant capability settings**

In `Obfuskoder.xcodeproj/project.pbxproj`, in **both** app-target `buildSettings` blocks (the Debug block ~line 412 and the Release block ~line 443 — the ones containing `INFOPLIST_FILE = "$(DERIVED_FILE_DIR)/Info-stamped.plist";`):

Remove these three lines from each block:
```
				ENABLE_APP_SANDBOX = YES;
				ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;
				ENABLE_USER_SELECTED_FILES = readwrite;
```
Add this line to each block (alphabetical order, near the other `C...` settings):
```
				CODE_SIGN_ENTITLEMENTS = Obfuskoder/Obfuskoder.entitlements;
```

(Equivalent Xcode-UI route: target → Build Settings → set *Code Signing Entitlements* to `Obfuskoder/Obfuskoder.entitlements`, and remove the App Sandbox / Outgoing Network / User Selected File capabilities so the file is the single source of truth.)

- [ ] **Step 4: Generate the EdDSA signing key (one-time, manual)**

Run: `SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*/artifacts/sparkle/Sparkle/bin' 2>/dev/null | head -1)" && "$SPARKLE_BIN/generate_keys"`
Expected: creates a private key in the login Keychain and prints a base64 **public** key. Copy that public key.
**Back up the private key now (store securely, NOT in the repo):** `"$SPARKLE_BIN/generate_keys" -x sparkle_private_key.pem` — move `sparkle_private_key.pem` to secure storage and delete the local copy. Losing this key breaks updates for all installed copies.

- [ ] **Step 5: Add the Sparkle keys to Info.plist**

In `Config/Info.plist`, add inside the top-level `<dict>` (paste the real key from Step 4 in place of the placeholder):

```xml
	<key>SUFeedURL</key>
	<string>https://updates.aldosoft.com/obfuskoder/appcast.xml</string>
	<key>SUPublicEDKey</key>
	<string>REPLACE_WITH_BASE64_PUBLIC_KEY_FROM_generate_keys</string>
	<key>SUEnableInstallerLauncherService</key>
	<true/>
	<key>SUEnableAutomaticChecks</key>
	<true/>
```

- [ ] **Step 6: Build and verify the entitlements are exactly right**

Run: `xcodebuild -scheme Obfuskoder -configuration Debug build 2>&1 | tail -3 && APP="$(xcodebuild -scheme Obfuskoder -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/{print $3; exit}')/Obfuskoder.app" && codesign -d --entitlements - "$APP" 2>/dev/null`
Expected: `** BUILD SUCCEEDED **` and the entitlements now show the original three (`app-sandbox`, `network.client`, `files.user-selected.read-write`) **plus** `temporary-exception.mach-lookup.global-name = [com.aldosoft.Obfuskoder-spki]` — nothing missing, nothing extra.

- [ ] **Step 7: Smoke-run the app**

Run: `open "$APP"` — confirm it launches, the main window appears, and encoding still works (sandbox/file access intact). Quit.

- [ ] **Step 8: Commit**

```bash
git add "Obfuskoder/Obfuskoder.entitlements" "Obfuskoder.xcodeproj/project.pbxproj" "Config/Info.plist"
git commit -m "Migrate to explicit entitlements file; add Sparkle Info.plist keys

Adds the Sparkle mach-lookup exception (installer XPC) and SU* keys.
Entitlements move from ENABLE_* build settings to Obfuskoder.entitlements
so the sandbox set is explicit and the mach-lookup array is expressible.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `SoftwareUpdater` wrapper + app wiring

Create the one Sparkle-importing type, wire it into the app, and apply the stored cadence at launch.

**Files:**
- Create: `Obfuskoder/SoftwareUpdater.swift`
- Modify: `Obfuskoder/SettingsKeys.swift` (add `updateFrequency` key)
- Modify: `Obfuskoder/ObfuskoderApp.swift` (instantiate + inject)

**Interfaces:**
- Consumes: `UpdateFrequency`, `AppConfig.defaultUpdateFrequency` (Task 2).
- Produces:
  - `@MainActor @Observable final class SoftwareUpdater`
  - `var canCheckForUpdates: Bool` (read-only, observable)
  - `func checkForUpdates()`
  - `func apply(_ frequency: UpdateFrequency)`
  - `static let SettingsKeys.updateFrequency = "updateFrequency"`

- [ ] **Step 1: Add the settings key**

In `Obfuskoder/SettingsKeys.swift`, add inside `enum SettingsKeys`:

```swift
    static let updateFrequency = "updateFrequency"
```

- [ ] **Step 2: Create `SoftwareUpdater`**

Create `Obfuskoder/SoftwareUpdater.swift`:

```swift
import Foundation
import Combine
import Sparkle
import ObfuskoderKit

/// Owns the Sparkle updater and adapts it to the app. The only file that
/// imports Sparkle. Applies the user's `UpdateFrequency` and republishes
/// Sparkle's `canCheckForUpdates` so the menu item can enable/disable.
@MainActor
@Observable
final class SoftwareUpdater {
    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var cancellable: AnyCancellable?
    private(set) var canCheckForUpdates = false

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        // Apply the persisted cadence (default monthly) before the first check.
        let stored = UserDefaults.standard.string(forKey: SettingsKeys.updateFrequency)
            .flatMap(UpdateFrequency.init(rawValue:)) ?? AppConfig.defaultUpdateFrequency
        apply(stored)

        // Republish Sparkle's KVO-observable canCheckForUpdates on the main actor.
        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.canCheckForUpdates = value }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    func apply(_ frequency: UpdateFrequency) {
        let updater = controller.updater
        updater.automaticallyChecksForUpdates = frequency.automaticallyChecks
        if let interval = frequency.checkInterval {
            updater.updateCheckInterval = interval
        }
    }
}
```

- [ ] **Step 3: Instantiate and inject in `ObfuskoderApp`**

In `Obfuskoder/ObfuskoderApp.swift`, add the state property (after `store`):

```swift
    @State private var softwareUpdater = SoftwareUpdater()
```

Change the `Settings` scene to inject it:

```swift
        Settings {
            SettingsView()
                .environment(model)
                .environment(softwareUpdater)
        }
```

(The `.commands { AppCommands(model: model) }` call is updated in Task 5.)

- [ ] **Step 4: Build and smoke-run**

Run: `xcodebuild -scheme Obfuskoder -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **` (this fully exercises Sparkle linking). Then `open "$APP"` — app launches, no crash; Console shows no Sparkle fault. Quit.

Resolve any Swift 6 concurrency warnings from the Combine `sink` (the class is `@MainActor`; `.receive(on: RunLoop.main)` keeps the closure on main) before committing — apply the swift-concurrency-pro guidance if needed.

- [ ] **Step 5: Commit**

```bash
git add "Obfuskoder/SoftwareUpdater.swift" "Obfuskoder/SettingsKeys.swift" "Obfuskoder/ObfuskoderApp.swift"
git commit -m "Add SoftwareUpdater wrapper; start Sparkle at launch with stored cadence

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: "Check for Updates…" menu item

**Files:**
- Create: `Obfuskoder/Views/CheckForUpdatesView.swift`
- Modify: `Obfuskoder/AppCommands.swift` (add param + command group)
- Modify: `Obfuskoder/Strings.swift` (add string)

**Interfaces:**
- Consumes: `SoftwareUpdater` (Task 4).
- Produces: `AppCommands(model:softwareUpdater:)` initializer signature.

- [ ] **Step 1: Add the UI string**

In `Obfuskoder/Strings.swift`, add under the menu strings (near `installCLITool`):

```swift
    static let checkForUpdates = String(localized: "Check for Updates…")
```

- [ ] **Step 2: Create the command view**

A dedicated `View` (not raw `Button` in the `Commands` body) so it reliably observes `canCheckForUpdates` — Sparkle's documented SwiftUI pattern. Create `Obfuskoder/Views/CheckForUpdatesView.swift`:

```swift
import SwiftUI

/// The Check for Updates… menu item. A View (not a bare Button in Commands) so
/// its disabled state tracks the updater's observable `canCheckForUpdates`.
struct CheckForUpdatesView: View {
    let updater: SoftwareUpdater

    var body: some View {
        Button(UIStrings.checkForUpdates) { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
    }
}
```

- [ ] **Step 3: Add the parameter and command group in `AppCommands`**

In `Obfuskoder/AppCommands.swift`, add the stored property:

```swift
    let softwareUpdater: SoftwareUpdater
```

Add a command group immediately after the About group (`CommandGroup(replacing: .appInfo)`):

```swift
        // Obfuskoder ▸ Check for Updates… — standard spot, just below About.
        CommandGroup(after: .appInfo) {
            CheckForUpdatesView(updater: softwareUpdater)
        }
```

- [ ] **Step 4: Pass the updater from `ObfuskoderApp`**

In `Obfuskoder/ObfuskoderApp.swift`, update the commands call:

```swift
        .commands { AppCommands(model: model, softwareUpdater: softwareUpdater) }
```

- [ ] **Step 5: Build and verify the menu**

Run: `xcodebuild -scheme Obfuskoder -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`. Then `open "$APP"` and confirm the **Obfuskoder** menu shows **Check for Updates…** just below About; clicking it opens Sparkle's checking UI (it may report "You're up to date" against the placeholder feed). Quit.

- [ ] **Step 6: Commit**

```bash
git add "Obfuskoder/Views/CheckForUpdatesView.swift" "Obfuskoder/AppCommands.swift" \
        "Obfuskoder/ObfuskoderApp.swift" "Obfuskoder/Strings.swift"
git commit -m "Add Check for Updates… menu item

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: "Software Updates" Settings section

**Files:**
- Modify: `Obfuskoder/Views/SettingsView.swift`
- Modify: `Obfuskoder/Strings.swift`

**Interfaces:**
- Consumes: `SoftwareUpdater` (via environment), `UpdateFrequency`, `AppConfig.defaultUpdateFrequency`, `SettingsKeys.updateFrequency`.

- [ ] **Step 1: Add the UI strings**

In `Obfuskoder/Strings.swift`, add near the other settings strings:

```swift
    static let settingsSoftwareUpdates = String(localized: "Software Updates")
    static let settingsCheckFrequency = String(localized: "Check for updates:")
    static let checkForUpdatesNow = String(localized: "Check Now")
    static let updateFrequencyDaily = String(localized: "Daily")
    static let updateFrequencyWeekly = String(localized: "Weekly")
    static let updateFrequencyMonthly = String(localized: "Monthly")
    static let updateFrequencyNever = String(localized: "Never")
```

- [ ] **Step 2: Add the section to `SettingsView`**

In `Obfuskoder/Views/SettingsView.swift`, add the imports/properties at the top of the struct (alongside the existing `@AppStorage` lines):

```swift
    @Environment(SoftwareUpdater.self) private var updater
    @AppStorage(SettingsKeys.updateFrequency) private var frequency = AppConfig.defaultUpdateFrequency
```

Add this `Section` inside the `Form`, after the fallback-message section:

```swift
            Section(UIStrings.settingsSoftwareUpdates) {
                Picker(UIStrings.settingsCheckFrequency, selection: $frequency) {
                    Text(UIStrings.updateFrequencyDaily).tag(UpdateFrequency.daily)
                    Text(UIStrings.updateFrequencyWeekly).tag(UpdateFrequency.weekly)
                    Text(UIStrings.updateFrequencyMonthly).tag(UpdateFrequency.monthly)
                    Text(UIStrings.updateFrequencyNever).tag(UpdateFrequency.never)
                }
                .onChange(of: frequency) { updater.apply(frequency) }

                Button(UIStrings.checkForUpdatesNow) { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
```

Add `import ObfuskoderKit` at the top if not already present (it is).

- [ ] **Step 3: Build and verify Settings**

Run: `xcodebuild -scheme Obfuskoder -configuration Debug build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`. Then `open "$APP"`, open **Settings…** (⌘,), confirm a **Software Updates** section with a cadence picker defaulting to **Monthly** and a **Check Now** button. Change the picker to Weekly, quit, relaunch, reopen Settings → it still reads Weekly (persistence). Quit.

- [ ] **Step 4: Commit**

```bash
git add "Obfuskoder/Views/SettingsView.swift" "Obfuskoder/Strings.swift"
git commit -m "Add Software Updates settings section (cadence + Check Now)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Release-flow signing + appcast generation

Extend `scripts/release.sh` to sign the zip and append a signed entry to a repo-tracked appcast; document the manual upload.

**Files:**
- Create: `updates/obfuskoder/appcast.xml`
- Modify: `scripts/release.sh`
- Modify: `docs/RELEASING.md`

- [ ] **Step 1: Create the appcast skeleton**

Create `updates/obfuskoder/appcast.xml`:

```xml
<?xml version="1.0" standalone="yes"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
	<channel>
		<title>Obfuskoder</title>
		<link>https://updates.aldosoft.com/obfuskoder/appcast.xml</link>
		<description>Software updates for Obfuskoder.</description>
		<language>en</language>
		<!-- ITEMS: newest first; entries below are appended by scripts/release.sh -->
	</channel>
</rss>
```

- [ ] **Step 2: Add the sign-and-appcast step to `release.sh`**

In `scripts/release.sh`, insert before the final `echo "== Done =="` block (after `FINAL_ZIP` is created and `ditto` has zipped it). The script gains an optional first argument: a release-notes file whose contents are embedded (as-is, wrapped) in the appcast entry.

```bash
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
```

- [ ] **Step 3: Test sign_update + appcast generation against the existing zip**

If `dist/Obfuskoder-1.0b5.zip` still exists, dry-run just the signing + XML assembly logic (or re-run a full release later). Minimum check now — confirm the tool signs and the XML validates:

Run: `SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*/artifacts/sparkle/Sparkle/bin' 2>/dev/null | head -1)"; ls "$SPARKLE_BIN/sign_update" && xmllint --noout updates/obfuskoder/appcast.xml && echo OK`
Expected: prints the `sign_update` path and `OK` (skeleton is well-formed). Full signing is exercised in Task 9 / the next real release.

- [ ] **Step 4: Update `docs/RELEASING.md`**

Append a "Software updates (Sparkle)" section documenting: the appcast lives at `updates/obfuskoder/appcast.xml` (committed) and must be uploaded to `updates.aldosoft.com/obfuskoder/`; the release command now takes an optional notes file: `scripts/release.sh path/to/notes.md`; the EdDSA private key lives in the Keychain and **must be backed up** (losing it breaks updates for installed copies); the `SUPublicEDKey` in Info.plist must match it.

- [ ] **Step 5: Commit**

```bash
git add scripts/release.sh docs/RELEASING.md updates/obfuskoder/appcast.xml
git commit -m "Release flow: sign build and append to Sparkle appcast

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: License, spec update, and pre-public secret scan

**Files:**
- Create: `LICENSE`
- Modify: `SPECIFICATION.md` (§9 network claim)

- [ ] **Step 1: Add the MIT license**

Create `LICENSE` (MIT). Use the standard MIT text with:
```
Copyright (c) 2026 Michael A. Alderete
```
(Adjust the holder name to a company if preferred.) Use the canonical MIT body verbatim.

- [ ] **Step 2: Update SPEC §9**

In `SPECIFICATION.md` §9 (network entitlement), replace the "no network / WKWebView-only" justification with: the app declares `com.apple.security.network.client` because **(a)** `WKWebView` needs it to launch its WebContent process and **(b)** Sparkle uses it to download updates from `updates.aldosoft.com` / GitHub Releases. Note the Sparkle Installer XPC mach-lookup exception (`$(PRODUCT_BUNDLE_IDENTIFIER)-spki`) and that entitlements now live in `Obfuskoder/Obfuskoder.entitlements`.

- [ ] **Step 3: Scan git history for secrets before the repo goes public**

Run: `git log -p --all | grep -nE 'BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY|SUPublicEDKey|sparkle_private|-----BEGIN' | head`
Expected: **no** private-key material. (The base64 `SUPublicEDKey` is public and fine.) Also confirm `sparkle_private_key.pem` was never committed: `git log --all --oneline -- '*private*key*' ; echo "(empty = good)"`.

- [ ] **Step 4: Commit**

```bash
git add LICENSE SPECIFICATION.md
git commit -m "Add MIT license; update SPEC §9 for Sparkle network use

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5: (User action) Make the repo public**

After the secret scan is clean, flip `alderete/Obfuskoder-Mac` to public in GitHub settings (Settings → General → Danger Zone → Change visibility). Required so Release assets are anonymously downloadable by Sparkle. *This is a manual GitHub action — not a code change.*

---

### Task 9: End-to-end live update test (mandatory gate)

Prove the whole cycle — download, signature/notarization validation, sandboxed XPC install, relaunch — before shipping any real update. This is runtime-only, like the preview's WebContent process, so it cannot be skipped or replaced by unit tests.

**Files:** none (a verification procedure; may create throwaway files under a scratch dir).

- [ ] **Step 1: Build and notarize a baseline vN**

Run the full release for the current build (e.g. tag `1.0b6`): `scripts/release.sh`. This produces a notarized `dist/Obfuskoder-<tag>.zip` and appends an appcast entry. Install this build to `/Applications`.

- [ ] **Step 2: Build a higher vN+1 and sign it**

Make a trivial visible change (e.g. a temporary window-title suffix), bump by committing so `git rev-list --count HEAD` increases, build+notarize+sign it, and generate an appcast advertising this higher `sparkle:version`.

- [ ] **Step 3: Serve the test feed locally**

Serve the test appcast + zip from a local server: `cd <dir-with-appcast-and-zip> && python3 -m http.server 8080`. Temporarily point a test build's `SUFeedURL` at `http://localhost:8080/appcast.xml` with an ATS localhost exception (test builds only — never ship this).

- [ ] **Step 4: Run the update**

Launch the installed vN, choose **Check for Updates…**, and observe the full sequence: update found → release notes shown → Install → download → **EdDSA signature + Developer-ID/notarization validation passes** → sandboxed Installer XPC swaps the app → relaunch → About shows vN+1.
Expected: the app relaunches at vN+1 with no Gatekeeper or signature error.

- [ ] **Step 5: Revert test scaffolding**

Discard the temporary title change, the localhost `SUFeedURL`/ATS exception, and any throwaway commits. Confirm `SUFeedURL` is back to the production URL and the tree is clean.

---

## Self-Review

**Spec coverage:** Goal/UX → Tasks 4–6; feed/downloads → Tasks 3,7; repo public + MIT → Task 8; single feed → (no channel code, satisfied by omission); key custody → Task 3 (+ RELEASING.md in 7); `UpdateFrequency` Kit split → Task 2; `SoftwareUpdater` → Task 4; entitlements/Info.plist → Task 3; version comparison via `CFBundleVersion` → Task 7 (`sparkle:version` = build number); release flow/appcast → Task 7; testing incl. mandatory live test → Tasks 2 (unit) + 9 (e2e); SPEC §9 → Task 8. All covered.

**Placeholder scan:** The only intentional fill-in is `SUPublicEDKey` in Task 3 Step 5 (a value that can only exist after `generate_keys` runs — the step generates it immediately prior). No other TBDs.

**Type consistency:** `UpdateFrequency` / `automaticallyChecks` / `checkInterval` / `AppConfig.defaultUpdateFrequency` / `SettingsKeys.updateFrequency` / `SoftwareUpdater.canCheckForUpdates` / `checkForUpdates()` / `apply(_:)` / `AppCommands(model:softwareUpdater:)` used consistently across Tasks 2–6.

## Deviation from spec to flag

The spec said the appcast would embed the release notes via a **markdown→HTML** step. To avoid a hard dependency (macOS ships no markdown CLI), Task 7 pins a dependency-free approach: embed the notes file's text wrapped in `<pre>` (readable in Sparkle's dialog), or fall back to a link to the GitHub release notes. Full markdown→HTML (e.g. via `pandoc`) can be added later. Flag for user awareness.
