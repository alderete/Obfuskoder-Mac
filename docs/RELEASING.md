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

Day-to-day development is unaffected: Debug builds keep using the
Apple Development certificate via automatic signing.
