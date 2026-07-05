# Releasing Obfuskoder

`scripts/release.sh` produces a Developer-ID-signed, notarized, stapled build
in `dist/Obfuskoder-<tag>.zip`, ready to attach to a GitHub Release. It
archives whatever is checked out, so tag first:

```sh
git tag -a 1.0b4 -m "…"
scripts/release.sh
gh release create 1.0b4 dist/Obfuskoder-1.0b4.zip --prerelease --title "Obfuskoder 1.0b4" --notes "…"
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
