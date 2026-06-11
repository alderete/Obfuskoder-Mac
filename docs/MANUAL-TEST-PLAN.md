# Obfuskoder for macOS — Manual Test Plan (1.0b1)

A step-by-step script to exercise every user-facing feature, including valid and
invalid data states. Check each box as you go; note anything that deviates from
**Expected**. Items marked **(a11y)** need VoiceOver; **(appearance)** need a
light/dark switch.

**Build & launch:** in Xcode, ⌘R (or build and open `Obfuskoder.app`).

> **Console noise is expected.** When the preview loads, Xcode's console shows
> WebKit-in-sandbox messages (`pboard`, `RunningBoard`,
> `com.apple.runningboard.assertions.webkit`, `coreservicesd`, audio,
> `task name port right`, and a benign `networkd` line if you click a preview
> link). These are normal for a sandboxed `WKWebView` and are **not** failures.
> A real failure would be a blank preview plus `WebProcess ... does not exist`.

---

## 1. Launch & window

- [ ] 1.1 App launches; one window appears titled **Obfuskoder**.
- [ ] 1.2 Opens to an **empty Basic form** (no fields pre-filled); result pane shows the empty placeholder; **Copy is disabled**.
- [ ] 1.3 Window is **resizable**; drag the divider between panes — both panes stay usable; the window has a sensible minimum size.
- [ ] 1.4 There is **no "New Window"** item in the File/Window menus; ⌘N does nothing (single-window app).
- [ ] 1.5 Resize/move the window, **Quit (⌘Q)**, relaunch → window **size/position is restored**.
- [ ] 1.6 Close the window with **⌘W** → the **app quits** (single-window utility). Relaunch.

## 2. Mode switch (Basic / Advanced)

- [ ] 2.1 Toolbar shows a **Basic | Advanced** segmented control; Basic is selected.
- [ ] 2.2 Click **Advanced** → the input pane switches to the HTML editor. Click **Basic** → back.
- [ ] 2.3 **⌘1** selects Basic; **⌘2** selects Advanced (also available in the View menu).
- [ ] 2.4 Type something in Basic, switch to Advanced, type something there, switch back to Basic → **Basic values are still there** (each mode retains its own values for the session).

## 3. Basic form — valid data

Use `alderete@aldosoft.com` as the email throughout.

- [ ] 3.1 Enter **Email** + **Link text** (e.g. "Email me") → after ~0.4s a snippet appears in the **Obfuskoded snippet** box and the **Preview** shows the link.
- [ ] 3.2 The snippet contains **no `@`** and **no readable email** (it's a long number array). Eyeball it.
- [ ] 3.3 Add a **Link title** (e.g. "Contact Aldosoft") → in the Preview, **hover the link** → the title appears as a tooltip.
- [ ] 3.4 Add a **Subject** (e.g. "Hello there") → open **▸ Show decoded source** → the decoded `<a>` contains `?subject=Hello%20there` (space percent-encoded).
- [ ] 3.5 Put special characters in **Link text** (`A & B <x>`) → Show decoded source shows them **escaped** (`A &amp; B &lt;x&gt;`); the Preview renders "A & B <x>" correctly.
- [ ] 3.6 Put a quote in **Link title** (`q"o`) and `&` in **Subject** (`a & b`) → decoded source shows `title="q&quot;o"` and `?subject=a%20%26%20b`.

## 4. Basic form — invalid / empty data

For each, Expected = **no snippet, empty/placeholder result, Copy disabled** (no alert, no crash):

- [ ] 4.1 All fields empty.
- [ ] 4.2 Email = `not-an-email` (no `@`).
- [ ] 4.3 Email = `foo@bar` (no domain dot).
- [ ] 4.4 Email = `a b@example.com` (space).
- [ ] 4.5 Email = `two@@example.com`.
- [ ] 4.6 Valid email, **Link text empty**.
- [ ] 4.7 Valid email, Link text = `"   "` (spaces only).
- [ ] 4.8 Fix the email to a valid one with valid link text → snippet appears (recovers cleanly).

## 5. Field hints

For **each** Basic field (Email, Link text, Link title, Subject):

- [ ] 5.1 An **`info.circle`** icon sits at the trailing edge of the field.
- [ ] 5.2 **Hover** the icon → a help-tag tooltip shows the hint.
- [ ] 5.3 **Click** the icon → a popover shows the same hint; click away to dismiss.
- [ ] 5.4 Hint text matches the field (e.g. Email = "The email address to be obfuskoded.").

## 6. Advanced form

- [ ] 6.1 Switch to Advanced → a monospaced HTML editor with an `info.circle` hint.
- [ ] 6.2 Paste `<a href="mailto:alderete@aldosoft.com" title="email me">Email me</a>` → snippet + Preview render the link.
- [ ] 6.3 Paste richer markup, e.g. `<p>Reach <strong>me</strong>: <a href="mailto:alderete@aldosoft.com">here</a></p>` → Preview renders bold + link.
- [ ] 6.4 Add **leading/trailing spaces/newlines** around the HTML → Show decoded source shows it **trimmed**.
- [ ] 6.5 Include an emoji, e.g. `<a href="mailto:alderete@aldosoft.com">Email 😀</a>` → Preview shows the emoji; decoded source round-trips it exactly.
- [ ] 6.6 Empty the field → empty/placeholder result, Copy disabled.

## 7. Live encoding & debounce

- [ ] 7.1 Type continuously in a field → the snippet does **not** rebuild on every keystroke; it updates shortly after you **pause** (~0.4s default).
- [ ] 7.2 Make a small edit, then another → each settled edit produces a **fresh** snippet (the number array changes) even when the decoded link looks the same.
- [ ] 7.3 Open **Settings (⌘,)**, drag **Encoding delay** to ~1.0s → typing now waits longer before updating; drag to ~0.1s → snappier. Close Settings.

## 8. Result, Copy, decoded source

- [ ] 8.1 Try to **edit** the snippet text → you **cannot** (read-only), but you **can select** it.
- [ ] 8.2 Click **Copy** → **"Copied"** appears just left of the button for ~5s; the **button label does not change**. Paste into TextEdit → you get the full snippet.
- [ ] 8.3 Use **Edit ▸ Copy Snippet (⇧⌘C)** → same "Copied" feedback; paste verifies the snippet is on the clipboard.
- [ ] 8.4 Clear the form so there's no snippet → **Copy button is disabled** and the **Copy Snippet** menu item is disabled.
- [ ] 8.5 **▸ Show decoded source** expands to show the decoded HTML; it equals your input. Collapse it. The **View ▸ Show/Hide Decoded Source** menu item toggles the same disclosure.

## 9. Preview behavior

- [ ] 9.1 The Preview **renders** the decoded link (not blank).
- [ ] 9.2 Hovering a link shows the **title tooltip** (when a title is set) and a pointing-hand cursor — it *looks* interactive on purpose.
- [ ] 9.3 **Click the link** → it does **not** open Mail; a transient **"Preview is non-interactive"** hint appears just below the preview (~3s).
- [ ] 9.4 You **cannot select** the preview text.

## 10. Saved values (presets)

- [ ] 10.1 With a filled Basic form, **Saved values ▾ → Save Current Values…** → a sheet prompts for a name; enter `Personal` → Save. The menu now lists **Personal**.
- [ ] 10.2 Change the form, then **Saved values ▾ → Personal** → the form is **restored** to the saved values (mode + fields).
- [ ] 10.3 Save again with the name `Personal` (duplicate) → the sheet shows **"A saved set with that name already exists"** and offers **Replace** → Replace updates it.
- [ ] 10.4 Switch to Advanced, enter HTML, **File menu ▸ Save Current Values… (⌘S)** → the name sheet appears; save as `HTML snippet`. Recall it → mode switches to Advanced with that HTML.
- [ ] 10.5 **Saved values ▾ → Manage Saved Values…** → rename an entry (edit text, press Return), delete one (trash), and **drag to reorder** → the menu reflects all changes.
- [ ] 10.6 Delete all presets → the **Saved values** menu shows only **Save Current Values…** (no list, no Manage…).
- [ ] 10.7 Save a preset, **Quit and relaunch** → the preset is **still there** (persisted).

## 11. Clear Form + Undo

- [ ] 11.1 Fill the Basic form → **Clear Form** button clears all fields; result returns to empty.
- [ ] 11.2 With an empty active form, the **Clear Form** button and the **⌘K** menu item are **disabled**.
- [ ] 11.3 Fill the form, press **⌘K** → cleared (no confirmation dialog).
- [ ] 11.4 Press **⌘Z (Undo)** → the cleared values **come back**; **⇧⌘Z (Redo)** → cleared again.
- [ ] 11.5 Fill Basic, switch to Advanced and add HTML, switch back to Basic, **Clear Form** → only the **Basic** fields clear; switch to Advanced → its HTML is **untouched**.

## 12. Menus & keyboard

- [ ] 12.1 **Obfuskoder** menu: **About Obfuskoder**, **Settings… (⌘,)**, **Quit (⌘Q)** all work.
- [ ] 12.2 **Edit** menu: standard **Cut/Copy/Paste/Select All** work inside the text fields; below the standard block there's a **separator**, then **Copy Snippet (⇧⌘C)** and **Clear Form (⌘K)** grouped together, then a **separator**.
- [ ] 12.3 **View** menu: **Basic (⌘1)**, **Advanced (⌘2)**, **Show/Hide Decoded Source**.
- [ ] 12.4 A **Help** menu and standard **Window** menu are present.
- [ ] 12.5 **(a11y)** Full keyboard operation: Tab moves between fields; you can reach and trigger every control and menu without the mouse.

## 13. Settings

- [ ] 13.1 **⌘,** opens Settings.
- [ ] 13.2 **Encoding delay** slider ranges ~0.1–1.0s and shows the current value; changing it affects live-encode timing (see 7.3).
- [ ] 13.3 **No-JavaScript fallback message** field: type text → reflected in the snippet's `<span>` fallback (check Show decoded source / the snippet). Type an **`@`** → it is **stripped** (can't be entered), preserving the no-`@` guarantee.
- [ ] 13.4 Change both settings, **Quit and relaunch** → settings **persist**.

## 14. Appearance (light / dark)

- [ ] 14.1 **(appearance)** Switch System Settings ▸ Appearance to **Dark** → the app adapts (legible text, correct backgrounds); the **dusty-sage accent** is visible on the active mode segment / focus rings. Switch back to **Light** → also correct.

## 15. Text-field hygiene (Mac substitutions off)

- [ ] 15.1 In any field, type a straight double-quote `"` → it **stays straight** (not curly).
- [ ] 15.2 Type two hyphens `--` → they **stay** as hyphens (not an em-dash).
- [ ] 15.3 In the Advanced HTML field, type a deliberately misspelled word → no autocorrect mangling; HTML you paste is never altered.

## 16. Accessibility (VoiceOver)

Turn on VoiceOver (⌘F5).

- [ ] 16.1 Each Basic field is announced **with its label** ("Email address", etc.).
- [ ] 16.2 Each **info** affordance announces e.g. "Email address help" and reads the hint.
- [ ] 16.3 The **mode picker** announces as a control labeled "Input mode".
- [ ] 16.4 The **Copy** button is labeled; after copying, VoiceOver **announces "Copied"**.
- [ ] 16.5 The snippet and preview areas are reachable/announced. Turn VoiceOver off (⌘F5).

## 17. No-network (optional, advanced)

- [ ] 17.1 With a network monitor (e.g. Little Snitch, or Activity Monitor ▸ Network), exercise Basic + Advanced + preview → the app makes **no outbound connections** (the `network.client` entitlement is required for WKWebView but never used to connect).

## 18. Command-line tool (obfuskode)

> Requires a built app. CLI behavior details: SPECIFICATION-CLI.md §5–§6.

- [ ] **Install (writable folder):** Obfuskoder ▸ Install Command Line
      Tool…, choose a folder you can write to (e.g. `/opt/homebrew/bin` or
      `~/bin`). Success alert names the link path; for an off-PATH folder it
      adds the PATH hint. The link works: `obfuskode --version` prints the
      app's version (matches Finder ▸ Get Info).
- [ ] **Install (root-owned folder):** choose `/usr/local/bin` on a machine
      where it is root-owned. The failure alert explains, **Copy Command**
      puts a `sudo mkdir -p … && sudo ln -sf …` line on the clipboard; running
      it in Terminal produces a working link.
- [ ] **Already installed / replace:** re-running the flow to the same folder
      reports "already installed"; with a foreign file named `obfuskode` at
      the target it asks before replacing (Cancel is the default button);
      Cancel at the panel and at the alert leaves everything untouched.
- [ ] **Translocation guard:** launch a quarantined copy (or from a DMG) —
      the flow shows "Move Obfuskoder to your Applications folder first"
      instead of the panel.
- [ ] **Pipelines:** `pbpaste | obfuskode | pbcopy` and
      `obfuskode < in.html > out.html` work; output pasted into a real page
      renders the expected link; the snippet contains no `@`.
- [ ] **Exit codes:** `obfuskode` alone on a TTY prints usage and exits 64
      (does not hang); `obfuskode -e bad -t x` exits 65; success exits 0
      (`echo $?`).
- [ ] **Help window:** Help ▸ Command-Line Tool Help opens the small window;
      examples are selectable; ⌘W closes it.

---

## Appendix A — Test data

**Valid emails:** `alderete@aldosoft.com`, `a.b+c@sub.example.co.uk`
**Invalid emails:** `` (empty), `not-an-email`, `foo@bar`, `a b@example.com`, `two@@example.com`
**Special link text:** `A & B <x>` · **Special title:** `q"o` · **Special subject:** `a & b`
**Advanced HTML:**
- `<a href="mailto:alderete@aldosoft.com" title="email me">Email me</a>`
- `<p>Reach <strong>me</strong>: <a href="mailto:alderete@aldosoft.com">here</a></p>`
- `<a href="mailto:alderete@aldosoft.com">Email 😀</a>`

## Appendix B — What "pass" means for the core security property

For any produced snippet (Basic or Advanced), Show decoded source must equal your
input, and the snippet text must contain **no `@`** and **no readable copy of the
email address** — only a number array plus JavaScript. (This is also enforced
automatically by the encoder's self-check and the 48 package tests:
`cd "Obfuskoder Mac/ObfuskoderKit" && swift test`.)
