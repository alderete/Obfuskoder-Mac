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

- [x] **FORM-1** — Unify field-label style across modes (Basic is plain, Advanced
      is bold). Target: bold, on top, both modes. *(§2)*
      **Fixed 2026-07-01** (with FORM-2, one restructure): `BasicFormView`
      rebuilt on AdvancedFormView's exact pattern — `.headline` label with the
      field's hint icon beside it, control underneath. Side-by-side Grid layout
      removed; fields now span the pane. Pane `minWidth` restored 370→320
      (labels-on-top compresses gracefully; re-verified no clipping at divider
      extremes in both modes). Manual-test §5.1 wording updated 2026-07-01 to
      match (hint icons sit beside the label, per MA sign-off).
      **Addendum 2026-07-01:** all heading labels bumped 13pt→15pt bold via a
      shared `Font.appHeadline` (`Views/Typography.swift`); covers the four
      form/pane headings plus both sheet titles. Basic-form field text also
      bumped to 15pt regular (`NSFont.appFieldFont`). Both derive from the
      `.title3` text style — never fixed point sizes — so they scale with the
      user's system text-size setting. Advanced editor, Settings field, and
      body/caption sizes unchanged.
- [x] **FORM-2** — Consistent left-edge spacing/alignment of form elements between
      Basic and Advanced. *(§2)*
      **Fixed 2026-07-01** by the FORM-1 restructure. Verified via AX: every
      element in both modes shares the same leading x (labels, fields, editor,
      Saved values, Clear Form). Screenshots eyeballed in both modes.
- [x] **FORM-3** — Advanced HTML editor shows a scrollbar immediately; it should
      only appear when content overflows. *(§2)*
      **Fixed 2026-07-01:** `scroll.autohidesScrollers = true` in
      `MacTextEditor.makeNSView`. Verified by screenshot: empty editor shows no
      scroller; it appears only when content overflows.
- [x] **FORM-4** — Reposition the Saved values menu and Clear Form button (current
      placement is poor). *(§2)*
      **Fixed 2026-07-01** per MA's spec (two small changes, no toolbar revamp):
      (1) Clear Form right-aligned in the footer bar, Saved Values stays left
      (`Spacer()` in `SavedValuesBar`). (2) Saved Values converted from a
      borderless text menu to a standard **pull-down button** (bordered, menu
      indicator at trailing edge — SwiftUI `Menu`'s default macOS style; the
      old code opted out via `.menuStyle(.borderlessButton)`), retitled
      "Saved Values" (title case). Test plan §10 label references updated.
      **Addendum:** upgraded to a **combo (split) button** per MA — hairline
      divider between label and indicator (`Menu(_:content:primaryAction:)` /
      NSComboButton style). Split semantics: clicking the label = Manage Saved
      Values… (primary action, per MA); the indicator section opens the menu.
      Verified by screenshot + live click test (label click opens the Manage
      sheet).
- [x] **FORM-5** — Hint popover (clicked info icon) isn't sized for the text and
      truncates longer hints; size it to fit. *(§5)*
      **Fixed 2026-07-01:** the popover measured the Text at single-line ideal
      size, so `maxWidth` clamped width but kept one-line height. Now fixed
      256pt content width + `fixedSize(horizontal: false, vertical: true)` in
      `FieldHint.swift` so height is measured for the wrapped text. Verified by
      screenshot with the longest hint (Link text, 3 lines, no clipping).
      Also updated manual-test §5.1 wording for the FORM-1 hint-icon move
      (beside the label, not at the field's trailing edge).

## 5. Color & branding

- [x] **COLOR-1** — Use the branding color for the selected segment of the mode
      picker. *(§2)*
      **Fixed 2026-07-01:** neither SwiftUI's segmented Picker nor
      NSSegmentedControl honors an accent for the selected segment on modern
      macOS (`selectedSegmentBezelColor` tried and ignored), so the picker is
      now a custom SwiftUI capsule control (`Views/ModePicker.swift`): accent
      fill + white label on the selected segment, animated selection slide.
      **Geometry cleanup (MA feedback):** dropped the control's own gray track —
      three nested curves (system glass capsule / track / chip) could never sit
      concentric because the toolbar chrome pads horizontally more than
      vertically. Now chip-in-glass (macOS 26 pattern): taller chip whose cap
      radius tracks the system capsule concentrically. Second pass (MA still
      saw uneven gaps): pixel-measured the rendering — chip cap center sat 4px
      left of the glass cap center (gaps 6.25/4.5/2.25px at flat/45°/far
      point). +2pt horizontal inset per side fixed it; re-measured
      6.25/7.25/6.25px (±1px ≈ antialiasing + the glass's continuous
      curvature vs. our circular arc).
      A11y hand-built (group labeled "Input mode", labeled segments with
      selected trait — wired identically to controls that passed VO tests; SE
      can't read SwiftUI labels, so a quick VO re-listen of 16.3/16.1 is
      advised). Verified: segment click switches modes, menu ⌘1/⌘2 syncs back,
      accent renders (screenshot).
- [x] **COLOR-2** — Use the branding color for the Clear Form and Copy buttons.
      *(§2)*
      **Fixed 2026-07-01, revised 2026-07-02:** Copy is `.borderedProminent`
      (sage fill from the AccentColor asset, white label, gray when disabled).
      Clear Form deliberately keeps the standard bordered style — MA: clearing
      is a secondary function; only Copy gets the accent.
- [x] **COLOR-3** — "Copied" feedback should use the accent color and animate
      more. *(§8)*
      **Fixed 2026-07-02:** "Copied" now renders in the accent color, and the
      Copy button does a one-shot spring pulse (scale 1.0→1.07→1.0, 0.18s) on
      every copy — driven by a `copyCount` trigger in AppModel so repeat copies
      inside the 5s feedback window also pulse. Verified: copy via button puts
      the snippet on the clipboard (0 `@`s), Copied appears in sage.
      (Most Mac-assed alternative — symbol morph to a checkmark via
      `.contentTransition(.symbolEffect(.replace))` — noted but conflicts with
      test 8.2's "button label does not change".)
- [x] **COLOR-4** — Dark mode: text-selection color is light gray and makes
      selected white text hard to read. *(§14)*
      **Fixed 2026-07-02:** pixel-measured the dark-mode selection at #626A5D —
      the system's derivation of the sage accent collapses to muddy gray. New
      dynamic `NSColor.appTextSelection` (`Views/AppColors.swift`): true accent
      in dark (#768E65 measured behind white text), pale accent tint in light
      (#D8DED4 measured behind black text). Applied to the Basic fields' field
      editor (`NoSubstitutionTextField`) and the Advanced editor. Verified by
      pixel sampling in both appearances; MA confirmed 2026-07-03.
- [x] **COLOR-5** — CLI Help examples: selection highlight is hard to see; needs
      more contrast or use the system highlight color instead of the accent.
      *(§18)*
      **Fixed 2026-07-03:** two causes. (1) SwiftUI `.textSelection` offers no
      highlight-color control — examples are now AppKit-backed selectable
      labels (`SelectableCode` in `CLIHelpView.swift`) using the shared
      `appTextSelection` color from COLOR-4. (2) The pale light-mode tint was
      invisible on the gray `.quinary` box (#D1D8CC on #D9D9D9, measured) — the
      example block now sits on the white "live" surface with quaternary
      stroke, matching the snippet box (WIN-4 language). Verified by pixel
      sampling + screenshot; examples remain selectable (test §18).

## 6. Controls & affordances

- [x] **CTRL-1** — Add the Copy SF Symbol (two rectangles) to the Copy button.
      *(§8)*
      **Fixed 2026-07-02** (with COLOR-3): `doc.on.doc` added via
      `Button(_:systemImage:)`. Verified by screenshot.
- [x] **CTRL-2** — Replace the distracting "Preview is non-interactive" animation
      with a brief toast above the click point; no resizing of UI elements. *(§9)*
      **Fixed 2026-07-03:** toast is rendered *in-page* (HUD-style pill in the
      preview's wrapper HTML) so it anchors to the exact click coordinates and
      never touches SwiftUI layout; auto-hides after ~1.8s; clamps to the
      viewport (shows below the point when clicked near the top). The old
      layout-shifting SwiftUI hint row is removed; the VoiceOver announcement
      (A11Y-2) is retained. Test plan 9.3 updated. Verified by click +
      screenshot.
- [x] **CTRL-3** — View ▸ Show/Hide Decoded Source menu title should change
      dynamically to reflect the current disclosure state. *(§8)*
      **Fixed 2026-07-03:** menu title is now conditional ("Show Decoded
      Source" ↔ "Hide Decoded Source", two String Catalog entries). Verified
      live in both states (note: System Events reads stale menu titles unless
      the menu is physically opened). Test plan 8.5/12.3 updated.
- [x] **CTRL-4** — The encoding-delay value should be more visible / animated — a
      Mac-native treatment, not the current generic one. *(§7)*
      **Fixed 2026-07-03** per MA's spec: separate value readout removed;
      custom slider (`Views/DelaySlider.swift`) with a large Liquid Glass knob
      shaped like home plate (five-sided, point aimed at the tick marks), the
      live value inside the knob (bold 12pt callout, no "s" suffix — the unit
      stays on the range labels; MA refinement). Accent-filled track, ticks at 0.1s
      increments, snap to 0.05. `glassEffect` gated to macOS 26 with an
      ultraThinMaterial fallback (target is 14.0). Focus rings the knob, not
      the row (`focusEffectDisabled` + knob stroke); keyboard steps via
      `onMoveCommand` (onKeyPress is eaten by the Form's scroll view); drag
      grabs focus like NSSlider; a11y via `accessibilityAdjustableAction`
      (needs a VO listen at next a11y pass). Verified: click-to-jump, drag,
      and arrow keys all move the value (0.35→0.40→0.45→0.40 measured in
      defaults); value updates live inside the knob (screenshots at 0.25/0.55/
      0.80). One unexplained 0.25→0.55 jump during automation never
      reproduced — watch for phantom value changes in manual use.
- [x] **CTRL-5** — Settings: left-align the fallback-message text (right-align is
      an iOS-ism). *(§7)*
      **Closed 2026-07-03: already fixed by FIX-2** — swapping the SwiftUI
      `TextField` for `MacTextField` gave the field NSTextField's natural
      (left) alignment. Confirmed by screenshot.
- [x] **CTRL-6** — No-JavaScript field: when blank, show the default message as
      ghost/placeholder text. *(§13)*
      **Fixed 2026-07-03:** default message as `placeholder` on the Settings
      field, and `ContentView.syncSettings` treats a blank/whitespace value as
      "use the default" so the encoded snippet gets the default fallback too.
      Verified: ghost text shows in the blanked field; snippet contains the
      default message with the setting blank.
- [x] **CTRL-7** — ~~Should Settings have Cancel/Save buttons that close the
      window?~~ **Declined 2026-07-03 (MA):** live-apply + ⌘W is the macOS
      Settings convention; Save/Cancel would require pending-state handling
      and diverge from platform behavior. No change.

## 7. Menus, About & Help

- [x] **MENU-1** — About box should include a tagline, an attribution line, and a
      link to the project/product page (GitHub for now). *(§12)*
      **Fixed 2026-07-03:** standard About panel with custom credits
      (`AboutPanel.swift` via `orderFrontStandardAboutPanel(options:)`): MA's
      tagline, "Inspired by Enkoder.", and a clickable
      github.com/alderete/Obfuskoder-Mac link (URL in
      `AppConfig.projectPageURL`). Verified by screenshot.
- [x] **MENU-2** — Build system should update the version and build number
      automatically. *(§12)*
      **Fixed 2026-07-03:** marketing version stays hand-set
      (`MARKETING_VERSION`); build number = git commit count. Implementation:
      app converted from generated Info.plist to a template
      (`Config/Info.plist`, outside the synchronized group); a "Stamp Build
      Number" script phase copies it to `$(DERIVED_FILE_DIR)/Info-stamped.plist`
      (declared input/output, `alwaysOutOfDate`) and sets `CFBundleVersion` to
      `git rev-list --count HEAD`; `INFOPLIST_FILE` points at the stamped copy
      so plist processing and codesigning are dependency-ordered after the
      stamp. `ENABLE_USER_SCRIPT_SANDBOXING = NO` (script needs git).
      ⚠️ Naive in-place stamping of the processed plist breaks incremental
      code signatures — do not "simplify" back to that. Verified: clean +
      incremental builds show CFBundleVersion=62 (= commit count), valid
      signature, plist keys identical to the previously generated one;
      `obfuskode --version` still reports the marketing version.
- [x] **MENU-3** — Trim the Window menu of unnecessary items; don't list the CLI
      window unless it's actually open. *(§12)*
      **Fixed 2026-07-03:** `.commandsRemoved()` on the cli-help Window scene —
      no standing Window-menu entry (Help ▸ Obfuskoder CLI Help is the way in).
      Verified: Window menu now contains only system-standard items.
- [x] **MENU-4** — Add Help content for Obfuskoder itself, parallel to the CLI
      help. *(§12)*
      **Fixed 2026-07-03** per MA (compact window, content from spec/README):
      `ObfuskoderHelpView` — seven short paragraphs (what it does, Basic vs
      Advanced, live preview, the no-`@` guarantee, Saved Values, privacy,
      CLI pointer) with inline bold/code markdown. Help ▸ Obfuskoder Help
      (⌘?, replaces the default help-book item) opens it; ⌘W closes; no
      Window-menu entry. Needed `fixedSize(horizontal: false, vertical: true)`
      to avoid paragraph truncation (same trap as FORM-5). Test plan §18 CLI
      help menu name updated. Verified by screenshot + close test.
- [x] **MENU-5** — CLI help should be titled "Obfuskoder CLI Help" and use a
      monospace font for commands in the help text. *(§12)*
      **Fixed 2026-07-03:** Help-menu item and window title both "Obfuskoder
      CLI Help"; inline commands (`obfuskode`, `obfuskode --help`) marked as
      markdown inline code in the String Catalog entries and rendered
      monospaced via `AttributedString(markdown:)`. Verified by screenshot.

## 8. Mac-native custom UI (larger effort — do once layout is stable)

- [x] **MAC-1** — Saved-values reordering should use gripper handles with dynamic,
      animated reordering of the actual rows, not a moving insertion point with
      instant reordering. *(§10)*
      **Fixed 2026-07-03:** custom drag engine in `ManagePresetsSheet` (List's
      `onMove` can't do live-follow on macOS): dragging the gripper lifts the
      row (shadow + scale + zIndex), it tracks the pointer 1:1, others spring
      out of the way as thresholds cross; drop commits through `store.move`.
      ⚠️ Gesture must use `coordinateSpace: .global` — local space feeds back
      through the row's own offset and reads ~half the distance (found when a
      2-row drag landed 1 row short). Context menu (Move Up/Down/Delete) is
      the keyboard/a11y path. Verified: 2-row drags land exactly, order
      persists to presets.json.
- [x] **MAC-2** — Manage Saved Values panel: drop the ellipsis from the window
      title; redesign to look less generic / more Mac-native. *(§10)*
      **Fixed 2026-07-03:** title "Manage Saved Values" (menu item keeps its
      ellipsis per HIG). Rows on the app's white "live" surface (WIN-4
      language): gripper, mode glyph (envelope = Basic, `</>` = Advanced),
      edit-in-place plain-style name, secondary detail line (email / monospaced
      HTML snippet), hover-revealed trash, inset dividers; empty state message;
      list height scales 3–6 rows. Test plan 10.5 updated. Verified by
      screenshots + live rename/reorder/persistence. Open knob: first name
      field grabs focus when the panel opens (Return then renames instead of
      dismissing) — flag if it bothers.

## 8.5 Behavior changes (added after the original punch-list)

- [x] **BEH-1** — Link text defaults to the email address (requested 2026-07-04).
      **Built 2026-07-04, TDD:** `BasicFields.canonicalHTML()` now falls back
      to the trimmed email when link text is empty/whitespace (nil only for an
      invalid email) — 4 new Kit tests. UI: the Link text field shows the
      current email as live ghost text; Tab in the empty field fills it in
      with the email — focus stays put with the caret at the end of the
      inserted text (MA revision), a second Tab advances
      (`MacTextField.tabCompletion` via `control(_:textView:doCommandBy:)`
      on `insertTab`, consuming the Tab). CLI: `--email` no
      longer requires `--link-text`; omitted/blank falls back (usage guard and
      CLI-11 data error removed; command + core tests revised; --help text
      updated). Docs: SPECIFICATION.md field table, SPECIFICATION-CLI.md
      CLI-6/CLI-11/options table, test plan 3.1a + 4.6/4.7. Verified: 95 Kit/CLI
      tests green; live app (email-only snippet, ghost text, Tab fill) and
      embedded CLI (email-only encode, 0 `@`s) both exercised.

## 9. Testing gaps (re-test, not build)

- [ ] **TEST-1** — Window size/position restore on relaunch — re-test, being
      careful to relaunch the *same* app build. *(§1.5)*
- [ ] **TEST-2** — Settings persist across quit & relaunch. *(§13.4)*
- [ ] **TEST-3** — CLI translocation guard (quarantined copy / from DMG). *(§18)*
- [ ] **TEST-4** — CLI exit codes: usage→64, bad args→65, success→0. *(§18)*
- [ ] **TEST-5** — Help ▸ Command-Line Tool Help window opens, examples
      selectable, ⌘W closes. *(§18)*
