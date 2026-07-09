# Releasing Obfuskoder

`scripts/release.sh` produces a Developer-ID-signed, notarized, stapled build
in `dist/Obfuskoder-<tag>.zip`, ready to attach to a GitHub Release. It
archives whatever is checked out, so tag first:

```sh
git tag -a 1.0b4 -m "…"
scripts/release.sh
gh release create 1.0b4 dist/Obfuskoder-1.0b4.zip --prerelease --title "Obfuskoder 1.0b4" --notes "…"
```

## Verify the downloadable asset (don't skip — a `ditto` extract hides the bug)

`release.sh` checks the app in its export dir with `spctl`, but that does **not**
exercise how a user's download extracts. Because the app embeds
`Sparkle.framework` (a versioned bundle of symlinks), a zip that carries
AppleDouble `._*` companions breaks the framework's code seal when a *naive*
unarchiver expands it — Gatekeeper then rejects the app ("unsealed contents in an
embedded framework" / "cannot verify free of malware"). `release.sh` builds the
zip with `ditto … --norsrc --noextattr` to prevent this; verify each release the
way a user would, using **plain `unzip`, not `ditto`** (ditto masks the problem):

```sh
unzip -q dist/Obfuskoder-<tag>.zip -d /tmp/relcheck
# want zero output (no ._* files at the framework root):
ls -a "/tmp/relcheck/Obfuskoder.app/Contents/Frameworks/Sparkle.framework/" | grep '^\._'
# want: accepted — source=Notarized Developer ID
spctl -a -t exec -vvv "/tmp/relcheck/Obfuskoder.app"
```

The script: archives the Release configuration → exports with the
`developer-id` method (`Config/ExportOptions.plist`; also re-signs the
embedded `obfuskode` helper) → submits to Apple's notary service and waits →
staples the ticket → verifies with `spctl` and `codesign` → zips into `dist/`
(gitignored).

## One-time setup

1. **Developer ID Application certificate** — Xcode ▸ Settings ▸ Accounts ▸
   (your team) ▸ Manage Certificates… ▸ **+** ▸ *Developer ID Application*.
   Requires the Account Holder role on the Apple Developer account.

2. **Notarization credentials** — create an app-specific password at
   [account.apple.com](https://account.apple.com) (Sign-In and Security ▸
   App-Specific Passwords), then store it:

   ```sh
   xcrun notarytool store-credentials "Obfuskoder" \
       --apple-id <your-apple-id> --team-id 49E99H2Q84
   ```

The script's preflight checks both and explains what's missing.

## App metadata lives in Config/Info.plist

The build-number stamping (MENU-2) gives the app a *physical* Info.plist
template (`Config/Info.plist`) with `GENERATE_INFOPLIST_FILE = NO` — which
makes all `INFOPLIST_KEY_*` build settings **inert**: they are only consulted
when Xcode generates the plist. Consequently:

- Add or change app metadata (category, copyright, display name, …) in
  `Config/Info.plist`, not in Build Settings and not via the General tab.
- The General tab's App Category popup reads the (dead) build setting, so it
  displays as unset — that's expected. Setting it there recreates an inert
  setting; the shipping value is `LSApplicationCategoryType` in the template.

Day-to-day development is unaffected: Debug builds keep using the
Apple Development certificate via automatic signing.

## Software updates (Sparkle)

After the notarized zip is built, `scripts/release.sh` signs it with
Sparkle's `sign_update` and appends a new `<item>` to the repo-tracked
appcast at `updates/obfuskoder/appcast.xml`. This is a local, offline step —
no notarization or GitHub access is required — but it does need a Sparkle
build once resolved by Xcode (the `sign_update` tool ships in the SPM
artifact bundle under DerivedData; the script locates it dynamically).

- **Appcast location**: `updates/obfuskoder/appcast.xml` is committed to the
  repo, but Sparkle clients read it from
  `https://updates.aldosoft.com/obfuskoder/appcast.xml`. After the script
  updates the file and you commit it, **manually upload the updated
  `appcast.xml` to `updates.aldosoft.com/obfuskoder/`** — pushing to git does
  not publish it.
- **Release notes**: pass an optional notes file as the script's first
  argument: `scripts/release.sh path/to/notes.md`. Its contents are embedded
  as-is (wrapped in `<pre>`) in the appcast item's `<description>` — notes
  are authored in plain text/Markdown, with **no Markdown→HTML conversion**,
  so keep them simple. Without a notes file, the item links to the GitHub
  release page instead.
- **EdDSA signing key**: `sign_update` signs the zip with an EdDSA private
  key Sparkle generates and stores in the login Keychain (via Sparkle's
  `generate_keys` tool, one-time setup). **Back this key up** — if it's
  lost, existing installs can no longer verify (and therefore can't
  install) future updates, and there's no recovery path other than shipping
  a new public key and asking every user to reinstall manually.
- **`SUPublicEDKey`**: the public half of that same key lives in
  `Config/Info.plist` as `SUPublicEDKey` and must match the private key used
  to sign — if it's ever rotated, update `Config/Info.plist` and ship that
  change before generating any appcast entries signed with the new key.
