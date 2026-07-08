# Sparkle Software Updater — Design Spec

- **Date:** 2026-07-08
- **Branch:** `software-updater`
- **Status:** Approved design, pending implementation plan
- **Feature:** In-app update checking for Obfuskoder (macOS) via Sparkle 2.9.4

## 1. Goal

Add automatic, in-app software update checking so bug-fix and feature builds
reach users (currently all beta testers) without a manual re-download. Behavior:
background checks on a user-configurable cadence (default **monthly**), Sparkle's
standard "an update is available → here are the release notes → install?" flow,
plus an on-demand **Check for Updates…** menu item.

## 2. Requirements (decided during brainstorming)

- **Updater:** Sparkle 2.9.4, already added via SPM to the app target (change to
  `project.pbxproj` is currently uncommitted — committed as the first impl step).
- **Update UX:** auto-check + **ask to install** (not silent auto-install). A
  Settings control chooses the check cadence: **Daily / Weekly /
  Monthly (default) / Never**.
- **Feed URL:** `https://updates.aldosoft.com/obfuskoder/appcast.xml` — the user's
  own domain, path-per-app layout, portable (baked into each build, so it never
  needs migrating even if hosting moves). Uploaded **manually** for now.
- **Downloads:** the signed `.zip`s stay as **public GitHub Release assets**; the
  appcast's `<enclosure>` links point at those URLs. GitHub's CDN carries the
  multi-MB downloads; only the small `appcast.xml` is uploaded to the user's host.
- **Repo visibility:** `alderete/Obfuskoder-Mac` becomes **public** (required so
  Release assets are anonymously downloadable). Adds an **MIT `LICENSE`**.
- **Single feed, no channels** for now (every user is a beta user). Channels get
  added when a stable 1.0 track exists.
- **Key custody:** the user owns and backs up the EdDSA private key.

## 3. Architecture / components

Follows the existing Kit/app split (pure logic in `ObfuskoderKit`, platform glue
in the app — the same pattern as `PreviewNavigationPolicy` ↔ `PreviewWebView`).

### 3.1 `UpdateFrequency` — ObfuskoderKit (pure, Sparkle-free, unit-tested)
Enum `daily / weekly / monthly / never`. Pure mapping to Sparkle's two settings:

| Case | `automaticallyChecksForUpdates` | `updateCheckInterval` (seconds) |
|------|--------------------------------|--------------------------------|
| daily | true | 86_400 |
| weekly | true | 604_800 |
| monthly | true | 2_592_000 (30 days) |
| never | false | n/a |

This mapping is the one piece worth test-driving. Lives in the Kit so it's
covered by `swift test` with no Sparkle/WebKit dependency.

### 3.2 `SoftwareUpdater` — app target (`@MainActor`, `@Observable`)
The single file that imports Sparkle. Owns
`SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil,
userDriverDelegate: nil)`. Responsibilities:
- Expose `canCheckForUpdates: Bool`, bridged from Sparkle's KVO-observable
  `updater.canCheckForUpdates` (drives the menu item's enabled state).
- `checkForUpdates()` — forwards to the Sparkle updater (menu item + "Check Now").
- `apply(_ frequency: UpdateFrequency)` — writes the mapped values through to
  `updater.automaticallyChecksForUpdates` / `updater.updateCheckInterval`.

### 3.3 UI
- **Menu:** `Check for Updates…` via `CommandGroup(after: .appInfo)` in
  `AppCommands` (directly below About — the standard macOS location). Disabled
  while `!softwareUpdater.canCheckForUpdates`.
- **Settings:** a `Software Updates` `Section` in `SettingsView` — a `Picker`
  bound to the stored `UpdateFrequency` plus a `Check Now` button. Reuses the
  existing `@AppStorage` / `SettingsKeys` / `AppConfig` conventions; new
  `SettingsKeys.updateFrequency`, `AppConfig.defaultUpdateFrequency = .monthly`.

### 3.4 Wiring — `ObfuskoderApp`
Hold `SoftwareUpdater` in `@State`, pass it to `AppCommands`, inject it into the
`Settings` scene's environment, and call `apply(storedFrequency)` at launch so the
persisted cadence takes effect immediately.

## 4. Data flow (update lifecycle)

Launch → `SoftwareUpdater` starts the Sparkle updater, reads the stored
`UpdateFrequency`, applies it → Sparkle checks on schedule → if a newer build is
advertised, Sparkle shows its standard dialog with release notes → user clicks
Install → Sparkle downloads the zip (app has `network.client`), **validates the
EdDSA signature and the Developer-ID/notarization**, then the sandboxed
**Installer XPC service** swaps the app and relaunches. Settings changes and the
menu item route through `SoftwareUpdater` and take effect immediately.

**Version comparison (important):** `CFBundleShortVersionString` is `"1.0"` for
*every* beta, so Sparkle must compare builds by **`sparkle:version` =
`CFBundleVersion`** — the git-commit-count build number, which is monotonic
(85, 86, …). The appcast `<title>` carries the human-readable label
("Obfuskoder 1.0b6").

## 5. Entitlements & Info.plist (delicate — migration must preserve behavior)

The app currently has **no `.entitlements` file**; sandbox/network/files come from
`ENABLE_APP_SANDBOX`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS`,
`ENABLE_USER_SELECTED_FILES` build settings. Sparkle's required mach-lookup
exception is an array of custom strings and cannot be a build-setting toggle, so:

- **New `Obfuskoder/Obfuskoder.entitlements`**, explicitly containing:
  - `com.apple.security.app-sandbox` = true
  - `com.apple.security.network.client` = true
  - `com.apple.security.files.user-selected.read-write` = true
  - `com.apple.security.temporary-exception.mach-lookup.global-name` =
    `[ $(PRODUCT_BUNDLE_IDENTIFIER)-spki ]`
- Set `CODE_SIGN_ENTITLEMENTS` to that file and **remove the now-redundant
  `ENABLE_*` capability settings** (single source of truth).
- No `-spks` entry: the Downloader XPC service is not used because the app has
  `network.client`. `SUEnableDownloaderService` stays unset/NO.

- **`Config/Info.plist` additions:**
  - `SUFeedURL` = `https://updates.aldosoft.com/obfuskoder/appcast.xml`
  - `SUPublicEDKey` = base64 ed25519 public key (from `generate_keys`)
  - `SUEnableInstallerLauncherService` = `YES` (required for sandboxed installs)
  - `SUEnableAutomaticChecks` = `YES` — we own the cadence via Settings, so we
    suppress Sparkle's first-run permission prompt (consistent with default-monthly).

- **Verification:** after building, confirm the shipped entitlements with
  `codesign -d --entitlements - <path>/Obfuskoder.app`. The migration must
  reproduce the current sandbox/network/file access exactly, plus the new
  mach-lookup exception — nothing more, nothing less.

## 6. Release flow & appcast

- **One-time key setup:** `generate_keys` creates the ed25519 pair; the public
  key goes in Info.plist; the private key lives in the login Keychain; the user
  exports and securely backs it up. A reminder is added to `docs/RELEASING.md`.
  (Losing the private key breaks the update chain for already-installed copies.)
- **`scripts/release.sh` gains a post-zip step:** `sign_update
  dist/Obfuskoder-<tag>.zip` → EdDSA signature + length. Then append/update a
  `<item>` in a repo-tracked **`updates/obfuskoder/appcast.xml`** with:
  - `<title>` (human label, e.g. "Obfuskoder 1.0b6")
  - `sparkle:version` = build number, `sparkle:shortVersionString` = "1.0"
  - `sparkle:minimumSystemVersion` = "14.0"
  - embedded release notes (`<description>` CDATA) derived from the same notes
    published to the GitHub Release (markdown→HTML step pinned in the plan)
  - `<enclosure url="https://github.com/alderete/Obfuskoder-Mac/releases/download/<tag>/Obfuskoder-<tag>.zip"
    sparkle:edSignature="…" length="…" type="application/octet-stream"/>`
- The script prints instructions to upload `updates/obfuskoder/appcast.xml` to
  `updates.aldosoft.com/obfuskoder/`. Tracking the appcast in git gives it a
  diffable history.
- The Sparkle CLI tools (`generate_keys`, `sign_update`) come from the Sparkle
  SPM artifact bundle; the plan pins their exact location / invocation and
  documents it in `RELEASING.md`.

## 7. Testing

- **Unit (Swift Testing, in Kit):** `UpdateFrequency` → settings mapping,
  including `never` disabling checks; persistence round-trip. Test-driven.
- **Build/link + entitlements:** full `xcodebuild` to confirm Sparkle links, and
  `codesign -d --entitlements -` to confirm the exact expected entitlement set.
- **End-to-end live update test (mandatory, before the first real release):**
  generate keys, build vN, host a *test* appcast advertising a signed vN+1, point
  a build at that feed, run Check for Updates…, and observe the whole cycle:
  download → signature/notarization validation → sandboxed XPC install →
  relaunch at vN+1. Like the preview's WebContent process, the sandboxed
  installer only exercises at runtime, so this cannot be skipped.

## 8. Scope / non-goals / prerequisites

- **In scope:** components above; MIT `LICENSE`; a **secret scan of git history**
  before the repo goes public (verify the private key was never committed).
- **User actions (outside the code):** flip the repo to public; back up the
  private key; upload the appcast after each release.
- **Non-goals (deferred):** beta/stable channels; silent auto-install; automated
  appcast upload.
- **Docs:** update **SPEC §9**'s "no network" statement to reflect Sparkle's use
  of `com.apple.security.network.client`.

## 9. Risks / things to verify during implementation

- **Entitlements migration** is the highest-risk change — a wrong or missing
  entitlement silently breaks the sandbox, file access, or the updater. Gate on
  the `codesign -d --entitlements` check and a smoke run of the app.
- **Sandboxed XPC install** behavior is runtime-only; the live update test is the
  real gate, not the build.
- Confirm whether Sparkle 2.9.x needs any additional plist/entitlement beyond the
  above by following the current Sparkle "Sandboxing" guide at build time (its
  setup has shifted across 2.x; do not rely on stale memory).
