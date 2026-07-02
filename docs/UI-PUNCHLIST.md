# Obfuskoder for macOS — Post-Test UI & Behavior Punch-List

Derived from the manual test pass in `MANUAL-TEST-2026-06-11.md` (notes, FAILs,
and untested items). Organized into a recommended working sequence. We'll work
through these one at a time; each has a **Details** line for you to fill in
before we implement it.

Legend: **FAIL** = failed test · **BUG** = behavior defect · **❓** = decision
needed before building · (no tag) = polish/enhancement.

---

## 1. Bugs (quick, self-contained)

- [x] **FIX-1** — ~~Undo stack records empty/no-op changes~~ **Closed 2026-07-01:
      no defect in the clear/restore code** (`AppModel.clearActiveForm`/
      `restoreForm` desk-checked; the ping-pong is correct and guards against
      no-op records). The observed symptom is explained by *typing-undo* groups
      sharing the window undo manager with the model-level clear/restore:
      programmatic text restoration leaves stale typing-undo entries that pop as
      visible no-ops. Folded into [[FIX-3]]. Repro if ever needed: type into two
      Basic fields → ⌘K → ⌘Z repeatedly.
- [x] **FIX-2** — Typing `@` in the No-JavaScript field strips the `@` but jumps
      the cursor to the end of the field; cursor should stay put. *(§13)*
      **Fixed 2026-07-01:** root cause was reactive stripping (`.onChange`
      reassigned the whole string after commit, resetting the insertion point).
      Now filtered at the field-editor level via `NoAtSignFormatter`
      (`SettingsView.swift`) delegating to `FallbackSanitizer` in ObfuskoderKit
      (10 new unit tests, incl. paste + UTF-16/emoji cursor math). The field is
      now a `MacTextField`, gaining the §15 substitution hygiene it was missing.
      Manual re-run of 13.3.5 passed 2026-07-01. **Addendum:** rejected `@`s
      (typed or pasted) now also trigger the system beep (`NSSound.beep()` in
      `NoAtSignFormatter`) so the user notices the strip — verified 2026-07-01.
- [ ] **FIX-3 ❓** — Undo-stack architecture (absorbs FIX-1): all undo sources
      (model clear/restore, Basic field editors, Advanced NSTextView) share the
      window undo manager, so stale typing-undo entries survive programmatic
      restores. Options: (a) cheap hardening — `removeAllActions()` before
      registering the clear record, making ⌘K/⌘Z/⇧⌘Z deterministic at the cost
      of typing-undo history; (b) separate undo managers per form / for the
      model. Also the original question: separate stacks for Basic vs. Advanced?
      *(§11)* **Details:**

## 2. Accessibility

- [x] **A11Y-1** — ~~Mode picker must announce as "Input mode"~~ **Closed
      2026-07-01: works as labeled.** The AXRadioGroup exposes
      `AXDescription = "Input mode"` (verified via live AX inspection; present
      since commit e55d11e, before the failed test), and a VO re-test confirmed
      VoiceOver announces "Input Mode" when the VO cursor reaches the toolbar.
      The original FAIL was a navigation artifact: VO starts at the first
      content element (Email field) and toolbars must be entered explicitly
      (VO+Shift+Down) — standard macOS behavior, not app-controlled. Reference
      apps (Finder, System Settings) expose only generic "radio group" here.
      Tab, by contrast, lands directly on the picker (keyboard focus stops on
      focusable controls only; a toolbar is never a Tab stop) and announces
      only the selected segment ("Basic"), not the group label — verified
      2026-07-01; identical to native behavior (e.g., Finder's view switcher),
      so accepted as-is.
- [x] **A11Y-2** — Activating the preview link via VoiceOver should announce that
      the preview is read-only / non-interactive (the visual message shows, but VO
      is silent). *(§16)*
      **Fixed 2026-07-01:** `flashPreviewHint()` (`ResultPane.swift`) now posts
      an `announcementRequested` accessibility notification with the
      "Preview is non-interactive" string, mirroring the proven "Copied"
      pattern from `copySnippet()` (test 16.4). Verified with VO 2026-07-01.

## 3. Window & pane layout (structural — do before fine visual polish)

- [x] **WIN-1 (FAIL)** — Window must be resizable and the pane divider draggable
      with both panes staying usable; minimum size must account for divider
      placement so form elements never get pushed offscreen. *(§1.3 + §1 notes)*
      **Fixed 2026-07-01:** reproduced programmatically (CGEvent divider drag +
      AX overflow check): at the left pane's declared `minWidth: 320` the four
      hint buttons overflowed the pane by 15pt (the screenshot from the manual
      test). Root cause: pane minimum (320) was less than the Basic form's real
      content minimum (~355: label column + 220pt field + hint + padding).
      Raised to 370 in `ContentView.swift`. Verified on a fresh build: no
      overflow at either divider extreme, in Basic and Advanced modes; window
      min (720×420) enforced. Note: FORM-1 (labels on top) will change the
      content minimum — revisit the 370 then. Discovered en route: `./build`
      is a stale June 11 artifact; see memory `stale-build-folder-trap`.
- [x] **WIN-2** — Rebalance the panes: the preview is bigger than it needs to be;
      the decoded-source area is smaller than it should be. *(§8)*
      **Fixed 2026-07-01** per MA's spec (~60%+ snippet / ~40%− preview+decoded;
      snippet is chunky code, preview is a one-liner): `ResultPane` now gives
      the snippet block a fixed 60% of the pane via GeometryReader; preview
      floor lowered 120→64; decoded source wrapped in a ScrollView. Verified by
      AX measurement: snippet block ≈65% of usable height at min window size.
- [x] **WIN-3** — Opening "Show decoded source" animates, with the preview
      collapsing to make room. *(§8)*
      **Fixed 2026-07-01** per MA's spec ("smart" squeeze): `PreviewWebView`
      reports its rendered document height after each load; while decoded
      source is open the preview pins to exactly that height (capped at 25% of
      the pane), the decoded area takes the rest, and the transition animates.
      Verified stable over repeated open/close cycles (open: preview 32pt
      content-pinned, decoded expands; closed: flexible 64pt floor). En route,
      found and fixed an observation-tracking heisenbug — conditionally-read
      state registered no dependency; see `pinnedPreviewHeight(paneHeight:)`
      comment and memory `swiftui-observation-short-circuit-trap`. Animation
      smoothness itself needs a quick human eyeball (AX can't judge motion).
- [x] **WIN-4** — Give the snippet an inset rectangle/box; decide whether it
      matches or differs from the Preview area's styling. *(§1)*
      **Fixed 2026-07-01** per MA's spec (same style to start, but snippet more
      "live"/selectable, preview more read-only): both boxes share rounded-6 +
      quaternary stroke; the snippet fills with `textBackgroundColor` (macOS's
      editable-text surface) in all states incl. empty/failure; the preview
      gets a gray wash (`.quinary` when empty; CSS
      `color-mix(Canvas 95%, CanvasText 5%)` when rendering, adapting to dark
      mode via system colors). Verified by screenshot in light mode; dark-mode
      eyeball pending (system colors should adapt — check alongside COLOR-4).
- [x] **WIN-5** — Distinct empty-state messages for the snippet box vs. the
      Preview. *(§1)*
      **Fixed 2026-07-01:** snippet: "Enter form values to generate a snippet";
      preview: "Preview renders once there's a snippet" (MA's wording verbatim,
      may be tweaked). In `UIStrings` via `String(localized:)` → String
      Catalog. Verified via AX that both render in the right places.

## 4. Form layout consistency (Basic ↔ Advanced)

- [ ] **FORM-1** — Unify field-label style across modes (Basic is plain, Advanced
      is bold). Target: bold, on top, both modes. *(§2)* **Details:**
- [ ] **FORM-2** — Consistent left-edge spacing/alignment of form elements between
      Basic and Advanced. *(§2)* **Details:**
- [ ] **FORM-3** — Advanced HTML editor shows a scrollbar immediately; it should
      only appear when content overflows. *(§2)* **Details:**
- [ ] **FORM-4** — Reposition the Saved values menu and Clear Form button (current
      placement is poor). *(§2)* **Details:**
- [ ] **FORM-5** — Hint popover (clicked info icon) isn't sized for the text and
      truncates longer hints; size it to fit. *(§5)* **Details:**

## 5. Color & branding

- [ ] **COLOR-1** — Use the branding color for the selected segment of the mode
      picker. *(§2)* **Details:**
- [ ] **COLOR-2** — Use the branding color for the Clear Form and Copy buttons.
      *(§2)* **Details:**
- [ ] **COLOR-3** — "Copied" feedback should use the accent color and animate
      more. *(§8)* **Details:**
- [ ] **COLOR-4** — Dark mode: text-selection color is light gray and makes
      selected white text hard to read. *(§14)* **Details:**
- [ ] **COLOR-5** — CLI Help examples: selection highlight is hard to see; needs
      more contrast or use the system highlight color instead of the accent.
      *(§18)* **Details:**

## 6. Controls & affordances

- [ ] **CTRL-1** — Add the Copy SF Symbol (two rectangles) to the Copy button.
      *(§8)* **Details:**
- [ ] **CTRL-2** — Replace the distracting "Preview is non-interactive" animation
      with a brief toast above the click point; no resizing of UI elements. *(§9)*
      **Details:**
- [ ] **CTRL-3** — View ▸ Show/Hide Decoded Source menu title should change
      dynamically to reflect the current disclosure state. *(§8)* **Details:**
- [ ] **CTRL-4** — The encoding-delay value should be more visible / animated — a
      Mac-native treatment, not the current generic one. *(§7)* **Details:**
- [ ] **CTRL-5** — Settings: left-align the fallback-message text (right-align is
      an iOS-ism). *(§7)* **Details:**
- [ ] **CTRL-6** — No-JavaScript field: when blank, show the default message as
      ghost/placeholder text. *(§13)* **Details:**
- [ ] **CTRL-7 ❓** — Should Settings have Cancel/Save buttons that close the
      window? *(§7)* **Details:**

## 7. Menus, About & Help

- [ ] **MENU-1** — About box should include a tagline, an attribution line, and a
      link to the project/product page (GitHub for now). *(§12)* **Details:**
- [ ] **MENU-2** — Build system should update the version and build number
      automatically. *(§12)* **Details:**
- [ ] **MENU-3** — Trim the Window menu of unnecessary items; don't list the CLI
      window unless it's actually open. *(§12)* **Details:**
- [ ] **MENU-4** — Add Help content for Obfuskoder itself, parallel to the CLI
      help. *(§12)* **Details:**
- [ ] **MENU-5** — CLI help should be titled "Obfuskoder CLI Help" and use a
      monospace font for commands in the help text. *(§12)* **Details:**

## 8. Mac-native custom UI (larger effort — do once layout is stable)

- [ ] **MAC-1** — Saved-values reordering should use gripper handles with dynamic,
      animated reordering of the actual rows, not a moving insertion point with
      instant reordering. *(§10)* **Details:**
- [ ] **MAC-2** — Manage Saved Values panel: drop the ellipsis from the window
      title; redesign to look less generic / more Mac-native. *(§10)* **Details:**

## 9. Testing gaps (re-test, not build)

- [ ] **TEST-1** — Window size/position restore on relaunch — re-test, being
      careful to relaunch the *same* app build. *(§1.5)*
- [ ] **TEST-2** — Settings persist across quit & relaunch. *(§13.4)*
- [ ] **TEST-3** — CLI translocation guard (quarantined copy / from DMG). *(§18)*
- [ ] **TEST-4** — CLI exit codes: usage→64, bad args→65, success→0. *(§18)*
- [ ] **TEST-5** — Help ▸ Command-Line Tool Help window opens, examples
      selectable, ⌘W closes. *(§18)*
