# Code-Review Fixes — Session Handoff (2026-07-06 → 07-07)

Purpose: capture everything from the multi-agent code review and the two rounds
of fixes, the two regressions found in manual testing, and the (partial)
diagnosis — so the improvements can be **re-applied slowly, with live testing**,
after reverting to the known-good **1.0b4**.

## TL;DR / current state

- All work lives on branch **`review-fixes`** (based on `main` = `fb12337`,
  "Merge branch 'ui': app category source of truth"). **Not merged.**
- Two review rounds were applied and committed; each was independently
  re-reviewed and (at commit time) built clean with the Kit/CLI test suite green.
- **Manual testing then surfaced two regressions:**
  1. **Preview pane renders blank.** (Root cause NOT fully confirmed — see below.
     Strong evidence it is a **high-contrast / `Canvas` CSS** interaction that may
     be **pre-existing in 1.0b4**, not caused by these changes.)
  2. **Undo (FIX-3) crashed** and mis-behaved. **Already reverted** to shipping
     behavior on the branch.
- Plan going forward: **revert to 1.0b4**, then re-apply the improvements in
  small, individually-verified steps (order suggested at the end).

> ⚠️ **Important caveat before assuming "revert fixes the preview":** the preview
> CSS implicated in the blank (`color-mix(in srgb, Canvas 95%, CanvasText 5%)` +
> `color: CanvasText`) is the pre-existing WIN-4 background and is **identical in
> 1.0b4**. If the blank is the high-contrast interaction (see diagnosis), it will
> **also affect 1.0b4**. First test after reboot: toggle **Increase Contrast off**
> and see whether the preview renders — in *either* build.

## Environment note (why the session halted)

Manual verification could not be driven from this automated environment (the app
launches windowless / GUI session is limited here), so UI checks depended on the
user. During diagnosis we found the user has **Increase Contrast ON**
(`effectiveAppearance = NSAppearanceNameAccessibilityAqua`). The user then found
**System Settings → Accessibility would not open** (adjacent panes did) — a system
glitch — and halted to reboot. That accessibility-pane failure may be related to
the same wedged high-contrast state.

---

## Commits on `review-fixes` (oldest → newest)

| SHA | Title | Keep / revisit |
|-----|-------|----------------|
| `e822f5d` | Fix high-impact issues from code review (round 1) | Mostly keep; FIX-3 portion already reverted |
| `e21eb81` | Fix minor issues from code review (round 2) | Keep (one part reverted) |
| `201bb0b` | Apply code-review taste decisions (mode checkmark + link hint) | Keep |
| `9d88b44` | Update link field hint text | **User's own commit** (string catalog) |
| `3cde553` | Fix blank preview (flag attempt); revert FIX-3 undo | superseded by 1780418 / 899d72f |
| `1780418` | Make preview navigation policy robust (scheme-based) | superseded by 899d72f context |
| `899d72f` | Revert preview re-measure-on-resize (blank-preview attempt) | current HEAD |

Net effect of the branch vs `main`/1.0b4 is summarized in the two round tables
below. The three "fix" commits at the end are the regression-response churn.

---

## Round 1 — high-impact fixes (all TDD'd)

| # | Fix | Files | Verdict |
|---|-----|-------|---------|
| 1 | **Escape the fallback message** before interpolating into snippet HTML (was raw → could inject `<script>` into the published page). `htmlEscapeText(fallbackMessage)` in `Encoder.buildArtifact`. | `ObfuskoderKit/Sources/ObfuskoderKit/Encoder.swift` | ✅ Solid, re-apply. Unit-tested. |
| 2 | **ENC-2 leak check scoped to the fallback** (standalone-word match) instead of scanning the whole snippet — short/common Advanced inputs (`a`, `var`, the default fallback text) were wrongly rejected. Plus **engine errors carry their cause** (`ObfuskodeError.selfCheckFailed(SelfCheckError)` / `selfCheckFailedRepeatedly(last:)`), and the CLI maps fallback-leak → **exit 65** (data) vs **70** (bug). | `SelfCheck.swift`, `ObfuskodeEngine.swift`, `ObfuskodeCLI/CLICore.swift`, `SPECIFICATION.md`, `SPECIFICATION-CLI.md` | ✅ Solid, re-apply. Unit-tested. |
| 3 | **Preview navigation policy** — block scripted `location`/`<meta refresh>` escapes from the read-only preview; only allow the in-memory load. New pure type `PreviewNavigationPolicy`. | `ObfuskoderKit/Sources/ObfuskoderKit/PreviewNavigationPolicy.swift` (new), `Obfuskoder/Views/PreviewWebView.swift` | ⚠️ Re-apply but **verify preview still renders** (see preview diagnosis — a headless probe + real-app logs show it *allows* the load, so it is likely NOT the blank cause, but it's entangled with the preview work). |
| 4 | **PresetStore preserves a corrupt store file** — moves `presets.json` aside (`.corrupt-<UTC stamp>`) before the next `save()` can overwrite it; empty/missing file is a clean start. | `PresetStore.swift` | ✅ Solid, re-apply. Unit-tested. |
| 5 | **FIX-3 undo** — whole-form undo helper (`FormUndo` / `FormUndoable`) clearing stale text-edit actions, making Apply-Preset undoable, weak undo-manager capture. | `FormUndo.swift` (new), `AppModel.swift`, `SavedValuesBar.swift`, `MacTextEditor.swift`, `Strings.swift` | ❌ **REVERTED** — crashed & mis-behaved. See undo analysis. Re-do properly with live testing. |

## Round 2 — minor fixes

| Fix | Files | Verdict |
|-----|-------|---------|
| **mailto: percent-encoding** (URI delimiters `? # % &` in local part) | `HTMLEscaping.swift` (`percentEncodeMailtoAddress`), `BasicFields.swift` | ✅ re-apply, unit-tested |
| **stdin read error surfaced** (was misreported as empty input); `readStdin` → `() throws -> Data?` | `ObfuskodeCommand.swift`, `CLICore.swift` | ✅ re-apply, unit-tested |
| **`SystemRandomSource: Sendable`** + `ScriptedRandom` range precondition | `RandomSource.swift`, `RandomSourceTests.swift` | ✅ re-apply |
| **Removed test-only branch** from `SelfCheck` (`extractFirstID`) | `SelfCheck.swift`, `ObfuskodeEngineTests.swift` | ✅ re-apply |
| **SF Symbol** `arrow.right.page.on.clipboard` (macOS 15) → `arrow.right.doc.on.clipboard` (macOS 11) — rendered blank on macOS 14 | `AppCommands.swift` | ✅ re-apply |
| **syncSettings clamp + sanitize** (debounce to `AppConfig` bounds; strip `@` from fallback from UserDefaults) | `ContentView.swift` | ✅ re-apply |
| **CLIToolInstaller TOCTOU** re-check after confirm dialog + surface removal error | `CLIToolInstaller.swift` | ✅ re-apply |
| **`disableIcons()` idempotent** (`didSwizzleIcons` guard) | `NSMenuItem+RSCore.swift` | ✅ re-apply |
| **presetsURL temp-dir fallback logged** (was silent) | `ObfuskoderApp.swift` | ✅ re-apply |
| **Disable ⌘S (Save Current Values) when active form is empty** | `AppCommands.swift` | ✅ re-apply |
| **Advanced editor font scales** with text-size setting (was fixed `NSFont.systemFontSize`) | `MacTextEditor.swift` | ✅ re-apply |
| **CLIHelpView `.fixedSize` anti-truncation** (matches ObfuskoderHelpView / MENU-4) | `CLIHelpView.swift` | ✅ re-apply |
| **Reduce Motion honored** (ModePicker slide, Copy pulse, decoded-source squeeze) | `ModePicker.swift`, `ResultPane.swift` | ✅ re-apply |
| **Preview re-measure on resize** (frame-change observer) | `PreviewWebView.swift` | ⚠️ **REVERTED** during blank-preview debugging (suspected then cleared). Re-add carefully + verify. |
| **Manage panel**: empty-rename reverts, rename commits on focus loss, delete/rename failures beep | `ManagePresetsSheet.swift` | ✅ re-apply |
| **release.sh** cleans temp dir on exit; removed dead `REGISTER_APP_GROUPS` | `scripts/release.sh`, `project.pbxproj` | ✅ re-apply |

## Taste decisions (from the user)

- **#1 Ghost-text contrast (BEH-2):** keep the light ghost text; instead added
  *"Defaults to the email address."* to the Link-text hint (help bubble + VoiceOver).
  ✅ applied (`Strings.swift` `linkTextHint`, catalog).
- **#2 ModePicker dark-mode selected contrast (3.6:1):** leave as-is.
- **#3 NotificationCenter → `@FocusedValue` refactor:** deferred/hold. (Also carries
  the residual "⌘S/Clear fire into the void when the main window is closed" case.)
- **#4 Basic/Advanced menu checkmark:** implemented as **Option A** — radio-style
  `Toggle`s in the View menu (checkmark on the active mode) that **keep ⌘1/⌘2**.
  ✅ applied (`AppCommands.swift`). *(Note: not visually verified live — confirm the
  checkmark tracks and ⌘1/⌘2 still switch when re-applied.)*

---

## Regression 1 — Preview pane blank (NOT fully root-caused)

**Symptom:** the Preview pane is empty; the "Obfuskoded snippet" pane and
"Show decoded source" both work. Reproduced in build 82 (normal launch).

**What was ruled OUT (with evidence):**
- **Navigation policy** — a headless WebKit probe *and* real-app NSLog both show the
  initial `loadHTMLString(baseURL: nil)` resolves to `about:blank` and is **allowed**
  (`decide navType=-1 url=about:blank -> allow`, `didFinish`). Even the original
  `.other → allow` allowed it. So the nav policy is **not** cancelling the load.
- **Frame-change observer** (round-2 re-measure) — reverted; still blank.
- **Sizing** — web view frame `{{0,0},{327.5,76}}`, `window=set super=set hidden=no`.
- **DOM / decode** — `document.body.innerText = "alderete@aldosoft.com"` (decodes
  correctly), `bodyHeight = 16`.
- **Colors** — computed: `color rgb(0,0,0)` (black), `bg color(srgb 0.95 0.95 0.95)`
  (light gray), `link rgb(0,0,238)` (blue). All visible values.

**The one anomaly / leading hypothesis:**
- `effectiveAppearance = NSAppearanceNameAccessibilityAqua` → **Increase Contrast is
  ON**. The preview HTML background uses CSS system colors + `color-mix`:
  ```css
  html,body{background:color-mix(in srgb, Canvas 95%, CanvasText 5%);color:CanvasText}
  ```
  These (`Canvas`, `CanvasText`, and `forced-colors`/`prefers-contrast` behavior) are
  exactly what WebKit treats specially under high-contrast. Hypothesis: content is in
  the DOM with sane computed colors but **is not painted** under high contrast.
- **This CSS is unchanged from 1.0b4**, so the blank may be **pre-existing** under
  Increase Contrast and **not** a regression from this work.

**Confirm-after-reboot (decisive tests):**
1. Toggle **Increase Contrast OFF** → does the preview render (in build 82 and/or
   1.0b4)? If yes → confirmed high-contrast/CSS interaction.
2. Launch **/Applications/Obfuskoder.app (1.0b4)** under the *current* settings →
   does *its* preview render? If also blank → environmental / pre-existing, not this
   work.

**Proposed fix (once confirmed):** replace `Canvas`/`CanvasText`/`color-mix` in the
preview CSS with explicit colors (and/or a `@media (prefers-contrast: more)` /
`forced-colors` branch) so it paints in both normal and high-contrast modes.
Consider pinning the web view's `appearance`.

**Diagnostic-run gotcha:** launching the binary attached to Terminal
(`.../MacOS/Obfuskoder 2>&1 | grep OBFPREVIEW`) causes **App Nap** — `evaluateJavaScript`
callbacks were delayed ~15s and the preview reloaded periodically. Those are
**launch artifacts**, not app bugs. Use a normal launch for timing-sensitive checks.

## Regression 2 — Undo (FIX-3) crashed — REVERTED

**Symptoms:** (a) undoing past the end of the stack **crashed** the app; (b) after
"delete Link title → Clear Form → ⌘Z", the undo reverted only the field edit, not the
Clear Form.

**Analysis:** the `FormUndo` whole-form approach doesn't actually coordinate with the
AppKit field-editor / `NSTextView` undo the way the plain-object unit tests implied.
Likely SwiftUI's `@Environment(\.undoManager)` is **not the same manager** the text
views register into (or a timing/ordering issue), and `removeAllActions()` destabilized
it. The unit tests passed because they used a stand-in object, not real text views.

**Action taken:** reverted to shipping behavior (deleted `FormUndo` + tests, restored
`AppModel`/`SavedValuesBar` from `main`, removed `breakUndoCoalescing` and the unused
`applyPreset` string). FIX-3 is **open again**.

**Proper approach (needs live ⌘Z testing):**
- Diagnostic first: log `ObjectIdentifier` of `\.undoManager` vs the focused
  `NSTextView.undoManager` — are they the same instance?
- Then either: **separate undo managers** (text views keep field-level undo; whole-form
  ops get a dedicated manager — mind ⌘Z routing), or **model-owned undo** with AppKit
  text undo disabled (`allowsUndo = false`) — coherent & crash-proof but loses
  per-keystroke undo (a UX tradeoff to confirm with the user).

---

## Suggested re-application order (slow, verified)

1. **Kit/CLI-only fixes** (fully unit-tested, zero UI risk): fallback escape (R1-1),
   ENC-2 scoping + error clarity (R1-2), PresetStore corrupt-file (R1-4), mailto
   encoding, stdin error, `RandomSource: Sendable`, SelfCheck cleanup, ScriptedRandom
   precondition. Run `swift test` (was 115–120 green depending on FIX-3 inclusion).
2. **Low-risk app fixes** (build + quick visual): SF Symbol, syncSettings clamp/
   sanitize, installer TOCTOU, `disableIcons` idempotency, presetsURL log, ⌘S disable,
   MacTextEditor font, CLIHelpView fixedSize, Reduce Motion, Manage-panel rename/delete,
   link hint, mode checkmark (Option A), config cleanup.
3. **Preview navigation policy** (R1-3) — re-apply, then **explicitly verify the preview
   still renders**, including with **Increase Contrast on**.
4. **Preview high-contrast fix** — the actual blank fix (explicit colors), verified with
   Increase Contrast toggled both ways.
5. **Preview re-measure on resize** — re-add carefully; verify no early-0-height
   collapse.
6. **FIX-3 undo** — dedicated effort with live ⌘Z testing (see approach above).

## Reference — verification techniques that worked here

- **Headless WebKit probe:** compile a tiny `main.swift` that links
  `PreviewNavigationPolicy.swift` + `-framework WebKit`, `loadHTMLString` the exact
  document, log navigations / `didFinish` / `evaluateJavaScript`. Runs without a window.
- **Real-app logging:** `NSLog("[OBFPREVIEW] …")` in `PreviewWebView`, launch attached
  (`.../MacOS/Obfuskoder 2>&1 | grep OBFPREVIEW`) — reliable capture (but App-Nap delayed).
- **Kit/CLI:** `cd ObfuskoderKit && swift test`. App: `xcodebuild build -scheme
  Obfuskoder -configuration Debug`. Build number = `git rev-list --count HEAD`.
- **Debug builds** put app code + string literals in `Obfuskoder.debug.dylib`, not the
  thin `MacOS/Obfuskoder` launcher — `strings`/inspection must target the dylib.
- **Stale copies to avoid launching:** `/Applications/Obfuskoder.app` (shipped 1.0b4)
  and `./build/…` (old June copy). The live one is under DerivedData `.../Debug/`.
