# Obfuskoder for macOS — Specification & PRD

**Status:** Draft v0.3
**Owner:** Michael A. Alderete, [Aldosoft](https://aldosoft.com/)
**Date:** 2026-06-06
**Platform:** macOS (Swift + SwiftUI)
**Companion document:** [MAC-ASSED-MAC-APPS.md](MAC-ASSED-MAC-APPS.md) — the
"Mac-assed Mac app" standard this product is held to.

---

## 1. Overview

Obfuskoder for macOS is a native, single-window desktop tool that converts an
email address (or an arbitrary HTML snippet containing an email address) into
an obfuscated HTML+JavaScript snippet the user can paste into their own web
page. When the snippet runs in a visitor's browser, the JavaScript decodes
itself and writes a normal `mailto:` link into the page. Email-harvesting bots
that parse HTML but do not execute JavaScript see only opaque code.

This is a native macOS recreation of the
[Obfuskoder web app](../Obfuskoder-JS/) — same product, same purpose, same
output contract. Only the *tool itself* changes: instead of a single
self-contained HTML page, it is a Swift/SwiftUI application that generates the
same kind of web snippet. The web-specific concerns of the original (single
`.html` file, no build step, browser support matrix, `file://` operation) are
removed; macOS-specific concerns (native UI, the menu bar, sandboxing,
notarization, light/dark appearance, local persistence) are added.

It is, deliberately, a **["Mac-assed Mac app"](MAC-ASSED-MAC-APPS.md)** in the
John Gruber sense: it follows the platform's conventions for layout, spacing,
keyboard control, menus, appearance, and behavior, rather than being a web app
in a window. Even though the app is simple, holding it to that standard is an
explicit project goal.

The product remains a recreation of the spirit of the Hivelogic Enkoder web
form (Dan Benjamin, 2006–2010s) — which itself once had a 2009 Mac desktop
version, **Enkoder.app**. Obfuskoder does **not** carry Hivelogic branding and
does **not** need to produce byte-identical output to the original.

## 2. Goals

- Give a non-technical Mac user a one-window way to turn an email address into
  a paste-ready obfuscated HTML snippet.
- Give a technical user a way to obfuscate an arbitrary HTML snippet (so the
  email address is not the only thing that can be hidden).
- Produce output that survives copy/paste into any CMS, static site, or
  hand-written HTML page, with no runtime dependencies in the consumer page.
- Verify, on every encode, that the produced snippet actually round-trips by
  executing it — the preview is real proof, not a mock-up.
- Be a genuinely native, conventional Mac app: keyboard-driven, menu-complete,
  appearance-correct, sandboxed, and notarization-ready.
- Be privacy-respecting: no network access of any kind, no telemetry; user data
  persists locally only, and only when the user explicitly asks for it.

## 3. Non-goals

- A web page, a browser extension, a WordPress plugin, a Rails helper, or a PHP
  library (prior art / the JS edition).
- Server-side anything: no backend, no accounts, no sync, no hosted service.
- Bulk encoding, address-harvesting protection on arbitrary pages, or scanning
  third-party content.
- Guaranteed defeat of sophisticated headless-browser harvesters. The output
  raises the *cost* of harvesting; it does not eliminate it. This caveat is
  shown to the user in-product.
- Telemetry, analytics, ads, crash reporting, or any outbound network call. The
  app must function fully with networking unavailable.
- iOS / iPadOS / visionOS versions (a Catalyst or multiplatform port is a
  possible future, not part of this spec).
- Producing anything other than the established web-snippet output contract
  (e.g., a plain `mailto:` string, a vCard, an image). Out of scope for v1.

## 4. Users & user stories

**Primary persona:** a Mac-using site owner who wants to publish a contact
email without exposing it as plaintext in their HTML.

| #     | As a…           | I want to…                                                        | So that…                                                  |
|-------|-----------------|-------------------------------------------------------------------|-----------------------------------------------------------|
| US-1  | site owner      | type my email, link text, optional title and subject              | I get a ready-to-paste obfuscated `mailto:` link          |
| US-2  | developer       | paste arbitrary HTML containing an email                          | I can obfuscate richer markup (image, span, etc.)         |
| US-3  | any user        | see what visitors will actually see, rendered from the real snippet| I trust the output before publishing it                  |
| US-4  | any user        | copy the encoded output in one action                             | I do not have to select-all-and-copy manually             |
| US-5  | keyboard user   | drive the whole app — fields, mode, copy, menus — from the keyboard| the tool is fast and usable with assistive tech          |
| US-6  | repeat user     | save a set of field values under a name and recall it later       | I do not retype the same addresses every time             |
| US-7  | Mac user        | have the app look and behave like a real Mac app in light and dark| it feels at home and trustworthy on my system            |

## 5. Platform & system requirements

- **Language / UI:** Swift, SwiftUI. AppKit interop only where SwiftUI lacks a
  capability (e.g., wrapping `WKWebView`).
- **Deployment target:** **macOS 14 Sonoma**.
- **Supported / tested:** macOS 14 Sonoma, macOS 15 Sequoia, macOS 26 Tahoe.
- **Architectures:** **Universal binary — Apple silicon and Intel.** This is a
  firm requirement: the app ships a universal build that runs natively on both
  architectures. (Not a "decide later" item.)
- **Design-language note:** on macOS 26 Tahoe the app adopts the system's
  current materials and toolbar treatment ("Liquid Glass") automatically by
  using standard SwiftUI/AppKit controls; on 14/15 it falls back to the
  standard appearance with no separate code path.
- **Minimum-OS watch list:** the spec calls out, where relevant, any place
  where raising the deployment target above 14 would meaningfully simplify the
  implementation (e.g., newer `WKWebView`, `Observation`, or SwiftUI APIs). See
  §14.

## 6. Functional requirements

### 6.1 Window & layout

- A **single window** (SwiftUI `Window` scene, not `WindowGroup`): the app has
  exactly one primary window, with no "New Window" command and no window
  tabbing.
- The window is **resizable**, with a sensible minimum size that keeps both
  panes usable. Its size and position are **restored across launches** via
  standard macOS state restoration.
- Layout is a **unified-toolbar, two-pane** design:
  - **Toolbar:** a segmented control to switch **Basic / Advanced** mode.
  - **Left pane (input):** the active form's fields, plus the **Saved values**
    control and a **Clear Form** button at the bottom (§6.7, §6.8).
  - **Right pane (result):** the obfuskoded snippet (read-only), a **Copy**
    action, a live **Preview**, and a **Show decoded source** disclosure (§6.6).
- The window opens to an **empty form** by default (no inputs are restored
  unless the user recalls a saved set — see §6.7).

ASCII sketch (wireframe, not final visuals):

```
+----------------------------------------------------------------+
| ● ● ●          [ Basic | Advanced ]                            |  ← toolbar
+------------------------------+---------------------------------+
| Email      [______________]  | Obfuskoded snippet              |
| Link text  [______________]  | +-----------------------------+ |
| Link title [______________]  | | <span id="OBFUSKODER_…">…   | |
| Subject    [______________]  | | </span><script>…</script>   | |
|                              | +-----------------------------+ |
|                              |                      [ Copy ]   |
| [ Saved values ▾ ] [ Clear ] | Preview                         |
|                              | +-----------------------------+ |
|                              | | Email me                    | |
|                              | +-----------------------------+ |
|                              | ▸ Show decoded source           |
+------------------------------+---------------------------------+
```

### 6.2 Mode switch (Basic / Advanced)

- A segmented control in the toolbar toggles between **Basic** and **Advanced**
  input modes. Exactly one mode is active at a time.
- Switching modes does not clear the other mode's field values within a session
  (both modes' working values are retained in memory until the app quits or the
  user recalls/clears them).
- Keyboard shortcuts select modes directly: **⌘1** = Basic, **⌘2** = Advanced
  (§6.9).

### 6.3 Basic form

Fields:

| Field        | Label (working) | Required | Validation / handling                                                            |
|--------------|-----------------|----------|----------------------------------------------------------------------------------|
| `email`      | Email address   | yes      | trimmed; must match a basic email pattern (`^[^\s@]+@[^\s@]+\.[^\s@]+$`)          |
| `linkText`   | Link text       | yes      | non-empty after trim                                                              |
| `linkTitle`  | Link title      | no       | any string; trimmed; becomes the `title=` attribute when present                  |
| `subject`    | Subject         | no       | any string; URL-encoded into the `mailto:` href as `?subject=` when present       |

- The canonical HTML built from a valid Basic form is:
  `<a href="mailto:EMAIL?subject=SUBJ" title="TITLE">TEXT</a>`, omitting
  `?subject=` and the `title` attribute when empty.
- That HTML string is what gets passed to the encoder (§7).
- **Validation feedback** is inline and non-modal: an invalid or incomplete
  Basic form shows a clear, accessible field-level message and puts the result
  pane in its empty/placeholder state (no snippet, Copy disabled). Validation
  must not interrupt typing with alerts.
- **Field hints.** Each Basic field carries the same explanatory hint as the web
  edition:

  | Field         | Hint                                                                                       |
  |---------------|--------------------------------------------------------------------------------------------|
  | Email address | *"The email address to be obfuskoded."*                                                    |
  | Link text     | *"The text users will see and click. Also obfuskoded, so you can repeat your email address."* |
  | Link title    | *"Pop-up message seen when the mouse hovers over the link."*                                |
  | Subject       | *"A pre-set subject line for the email. Supported by most email clients."*                  |

  Hints are presented the **macOS-idiomatic** way rather than as always-visible
  web-style caption text: a small **`info.circle` help affordance** at the
  trailing edge of each field. Hovering it shows the hint as a **help tag
  (tooltip)**; clicking it — or activating it from the keyboard — shows the same
  text in a **popover**, so the hint is reachable without a mouse. The hint is
  exposed to assistive technology as the field's **accessibility help/hint**, and
  the affordance carries an accessibility label (e.g., "Email address help"), so
  VoiceOver users get the same information. Hint strings live in the String
  Catalog (§9.5).

  *Design note:* an always-visible System Settings–style caption beneath each
  field was the considered alternative; the info affordance was chosen to keep
  the compact two-pane form uncluttered. Because the strings are externalized,
  switching presentation later is a low-cost change.

### 6.4 Advanced form

- A single multi-line text field labeled **HTML to obfuskode**, prefilled with a
  small placeholder example (e.g.,
  `<a href="mailto:user@example.com">Email me</a>`).
- The field carries a hint, shown via the same `info.circle` help affordance as
  the Basic form (§6.3): *"Paste arbitrary HTML. Whatever you enter will
  round-trip through Obfuskoder verbatim. (Surrounding whitespace is trimmed.)"*
- The trimmed contents are passed **verbatim** to the encoder. No HTML
  sanitization is performed — the user is explicitly opting into "paste whatever
  you want." This is safe because (a) the snippet is generated locally for the
  user's own use, and (b) the preview runs in an isolated WebKit context (§6.6,
  §9.2).
- Empty input → result pane shows the empty/placeholder state.

### 6.5 Live encoding & debounce

- There is **no "Obfuskode" button.** Encoding is **semi-live**: the app
  re-encodes automatically a short, configurable interval after the user stops
  changing the input ("debounce").
- **Default debounce delay: 400 ms.** The value is a single tunable constant
  (`AppConfig`) and is also exposed in the Settings window (§6.10) so the feel
  can be adjusted without rebuilding.
- Behavior:
  - While the input is invalid or empty, the result pane shows its
    empty/placeholder state and Copy is disabled.
  - When the input is valid, each debounced pass produces a fresh snippet (the
    encoder reseeds every pass, so the snippet legitimately changes — see
    ENC-6). The most recently shown snippet is what the user copies.
  - Encoding and the self-check (§7) run **off the main actor**; results are
    delivered on the main actor. Typing must never feel blocked.

### 6.6 Result pane

- **Obfuskoded snippet:** a **read-only**, selectable, monospaced text view
  showing the full snippet (sentinel `<span>` + inline `<script>`). The user can
  select and copy text manually, but cannot edit it.
- **Copy:** a Copy action (button + **Copy Snippet** menu command + **⇧⌘C**, §6.9)
  writes the snippet to the system pasteboard. Both paths share one code path and
  confirm success identically: a transient **"Copied"** label appears just left of
  the Copy button for ~5 seconds and is announced to VoiceOver. (The button label
  itself does not change.) Copy is disabled when there is no valid snippet.
- **Preview:** a **read-only**, non-interactive `WKWebView` that renders the
  **actual generated snippet** via `loadHTMLString` (no network, no `baseURL`),
  executing its JavaScript so the user sees exactly what a visitor would see.
  Navigation actions (e.g., clicking the `mailto:` link) are cancelled — the
  preview is a visual proof, not a launch surface. The preview text is not
  selectable, and clicking a link is intercepted (never navigates) and briefly
  shows a *"Preview is non-interactive"* hint beneath the preview.
  *Design intent:* the preview deliberately keeps an interactive **appearance**
  (e.g., hovering a link shows its `title` tooltip) so it reads as a real,
  complete rendering of what visitors get; the intercepted-click hint resolves
  the one expectation that can't be honored. Do not "fix" the clickable look.
- **Show decoded source:** a disclosure control that reveals the decoded HTML
  (which, by ENC-1, equals the user's input) so the user can verify the
  round-trip.

### 6.7 Saved values (named presets)

> **Naming note:** "Saved values" is a *working label*. Like all user-facing
> text it lives in the String Catalog (§9.5) and can be renamed/localized
> without code changes.

- A **Saved values** popup menu sits at the bottom of the input (left) pane.
- The menu contains, in order:
  1. **Save Current Values…** — captures the current form state and prompts for
     a **unique name** (a sheet with a text field and validation). The saved
     preset snapshots the **full form state**: the active mode (Basic or
     Advanced) and that mode's field values. Recalling it restores the user to
     exactly that state.
  2. A list of **previously saved names** — selecting one **loads** that preset
     into the form (switching mode if needed). The most recently used / a
     selected indicator may be shown.
  3. **Manage Saved Values…** — opens a sheet to **rename, delete, and reorder**
     saved presets.
- **Name uniqueness:** names must be unique. Saving with a name that already
  exists asks the user whether to **replace** the existing preset.
- **Storage:** presets are persisted as JSON (Codable) in the app's Application
  Support directory inside the sandbox container. They are stored **only** when
  the user explicitly saves them, **only** locally, and are **never
  transmitted** (§9.2).
- **Empty state:** with no presets saved, the menu shows only **Save Current
  Values…** (the list and **Manage…** appear once at least one preset exists).

### 6.8 Clear Form

- Both the Basic and Advanced forms provide a **Clear Form** action that resets
  the **currently active** form's fields to empty (the Advanced field returns to
  its placeholder example) and returns the result pane to its empty state.
- It is available two ways:
  - a **button** in the input pane, next to the Saved values control (§6.1); and
  - a **menu command with a keyboard shortcut** — **⌘K**, in the Edit menu
    (§6.9).
- Clear Form is **undoable** (it registers a standard Undo), so it shows **no
  confirmation alert** — consistent with Mac conventions. The action is disabled
  when the active form is already empty.
- Clearing affects **only the active form**; the other mode's in-memory values
  are untouched (§6.2), and **no saved presets are deleted** (§6.7).

### 6.9 Menu bar & keyboard shortcuts

The app ships a complete, conventional menu bar. Standard items behave
normally; app-specific commands are wired with shortcuts. (Exact titles live in
the String Catalog.)

- **Obfuskoder (app menu):** About Obfuskoder; Settings… (**⌘,**); standard
  Services, Hide, Quit (**⌘Q**).
- **File:** Save Current Values… (**⌘S**).
- **Edit:** standard Undo/Redo, Cut/Copy/Paste, Select All (free with native
  text controls); then the app's own commands, grouped together and fenced off by
  separators above and below — **Copy Snippet** (**⇧⌘C**) and **Clear Form**
  (**⌘K**, §6.8). (Pure SwiftUI `Commands`; no AppKit menu surgery.)
- **View:** Basic (**⌘1**) / Advanced (**⌘2**); Show/Hide decoded source.
- **Window:** standard window commands (Minimize, Zoom).
- **Help:** Obfuskoder Help (at minimum a link/About-style entry).
- The entire UI is operable from the keyboard alone, with visible focus, correct
  tab order, and no mouse-only paths.

### 6.10 Settings window

- A standard **Settings** scene (opened with **⌘,**) hosting at least:
  - **Encoding delay** — the debounce interval (§6.5), defaulting to 400 ms, so
    the typing feel can be tuned by the user/developer.
  - **Default fallback message** — the text shown to non-JavaScript visitors
    (default: *"Enable JavaScript to view email"*).
- Settings persist locally (UserDefaults) within the sandbox container.

## 7. Encoding algorithm requirements

The encoder's *contract* is inherited unchanged from the web edition — it is
platform-neutral because the **output is still a web snippet**. This spec
defines properties the encoder must satisfy, not one exact algorithm; v1 picks
an implementation that meets them and may be swapped later.

### 7.1 Required properties

| ID    | Property                                                                                                                                                                                                                 |
|-------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ENC-1 | **Round-trip correctness.** Executing the produced snippet in a JS environment yields exactly the input HTML string `s`, injected into the DOM at the snippet's location.                                                 |
| ENC-2 | **No reconstructable leakage.** The static text of the snippet contains no occurrence of `s`, no occurrence of the raw email address, and no occurrence of the local-part adjacent to the domain (or to an `@`-like delimiter). Incidental substring matches in unrelated context (e.g., a local-part `email` coinciding with the word "email" in the fallback message) are not leaks. |
| ENC-3 | **No `@` in static text.** The character `@` does not appear in the static snippet. (Heuristic harvesters key off `@`.)                                                                                                  |
| ENC-4 | **Self-contained.** The snippet pulls nothing over the network: no `src=`, no external resource, no import.                                                                                                              |
| ENC-5 | **Deterministic decode.** The decoder runs in bounded time (no infinite loops, no timers).                                                                                                                              |
| ENC-6 | **Non-deterministic encode.** Two encodes of the same input produce different output snippets (random seed per encode).                                                                                                  |
| ENC-7 | **AJAX-safe injection.** The snippet works when injected into a live DOM; it must not depend on post-parse `document.write`.                                                                                             |

### 7.2 Suggested implementation (informative, not normative)

The reference algorithm (carried over from the web edition; implementers may
choose any approach meeting §7.1):

1. Pick a per-encode random offset `k ∈ [3, 250]`.
2. With ~50% probability, pick a random XOR mask `m ∈ [1, 255]`.
3. Each input Unicode **code point** `cp` becomes `(cp + k) ^ m` (or `cp + k`
   when there is no mask). Operate on code points (`String.UnicodeScalarView`),
   not UTF-16 units, so emoji and non-BMP characters round-trip.
4. With ~50% probability, reverse the resulting integer array.
5. Emit a sentinel `<span id="OBFUSKODER_…">FALLBACK</span>` plus an inline
   `<script id="OBFUSKODER_…_s">` whose decoder finds the span by id, sets its
   `outerHTML` to the decoded HTML (AJAX-safe, ENC-7), then finds itself by id
   and removes itself.
6. The literal `</script>` only ever appears inside a runtime-built string,
   written in source as `<\/script>` so the consumer page's parser never sees a
   stray end tag.

The sentinel constant is `OBFUSKODER_…` — the legacy "Enkoder" name never
appears in shipped source or output.

### 7.3 Encode-time self-check (built in)

Before showing any result, the app asserts ENC-1/ENC-2/ENC-3 on the snippet it
just produced:

- **ENC-1 (round-trip):** execute the decoder in a headless **JavaScriptCore**
  (`JSContext`) against a **faked `document`** whose `getElementById` returns a
  stand-in that captures `outerHTML` writes; confirm the recovered string equals
  the input verbatim. (This is the direct Swift analog of the web edition's
  `new Function("document", body)` self-check.)
- **ENC-2:** confirm the static snippet text contains no occurrence of the input
  string, and — for a `mailto:` link — no occurrence of the bare email address.
  (The full adjacency clause needs no separate runtime check: every input code
  point becomes a number, so the local-part cannot appear adjacent to the domain
  in static text unless the whole input does, which is already checked.)
- **ENC-3:** confirm the static snippet text contains no `@`.

If any assertion fails, the result pane shows an error state and **no snippet is
displayed**. The encode+verify step retries up to **8 times** to absorb the
vanishingly rare random-id substring collision. The self-check runs **inside the
app at encode time**; it is **not** part of the snippet the user pastes
elsewhere.

> Two JavaScript runtimes are used by design: **JavaScriptCore** for the
> headless self-check (§7.3), and **WebKit (`WKWebView`)** for the visible,
> read-only preview (§6.6).

## 8. Architecture

The app separates a pure, testable core from the SwiftUI presentation layer.
Each unit has one purpose and a well-defined interface.

- **`ObfuskodeEngine`** — pure Swift, no UI/WebKit dependency. Encodes an input
  HTML string into the snippet (§7). `Sendable`; safe to run off the main actor.
  Randomness is injectable so encoding is deterministic under test.
- **`SnippetSelfCheck`** — runs ENC-1/2/3 (§7.3). Owns the JavaScriptCore-based
  round-trip check and the string checks. Independent of the UI.
- **`Snippet`** — a value type carrying the snippet string and any metadata
  (e.g., the decoded source for the disclosure).
- **Form models** — `@Observable` state for Basic fields, Advanced text, and the
  current mode. Hosts validation.
- **`EncodePipeline`** — debounces input changes (§6.5), invokes the engine +
  self-check off-main, and publishes the latest `Snippet` (or empty/error state)
  to the UI on the main actor.
- **`Preset` / `PresetStore`** — `Codable` preset model and an `@Observable`
  store that loads/saves presets as JSON in Application Support, enforces unique
  names, and supports rename/delete/reorder.
- **`UIStrings`** — typed access to the **String Catalog** (`.xcstrings`); no
  view hardcodes user-facing text.
- **`AppConfig`** — tunable constants (debounce default 400 ms, accent color,
  size budget, default fallback message).
- **Views** — `ContentView` (toolbar + two-pane), `InputPane` (Basic/Advanced +
  Saved values), `ResultPane` (snippet, Copy, Preview, decoded-source
  disclosure), `PreviewWebView` (`NSViewRepresentable` over `WKWebView`),
  `SaveValuesSheet`, `ManagePresetsSheet`, `SettingsView`.

The starter scaffold currently uses `WindowGroup` and a placeholder
`ContentView`; the implementation replaces these with the `Window` scene and the
views above.

## 9. Non-functional requirements

### 9.1 Sandboxing & distribution

- **App Sandbox is enabled**, with minimal entitlements:
  - **`com.apple.security.network.client`** — declared because a sandboxed
    `WKWebView` requires it to launch its WebContent process, *even for local,
    in-memory HTML*. Without it the WebContent process is denied and the preview
    stays blank. The app makes **no actual outbound requests**: the preview loads
    a self-contained snippet via `loadHTMLString(baseURL: nil)` with navigation
    cancelled, and there is no other networking code (§9.2). (Set via the
    `ENABLE_OUTGOING_NETWORK_CONNECTIONS` build setting.)
  - **No network *server* entitlement; no user-selected file access** — presets
    and settings live in the app's own container.
- The app is built to be **notarization-ready** and Developer ID–signable.
- **Distribution (v1):** direct download (notarized Developer ID), **not** the
  Mac App Store. Nothing in the design precludes a later MAS submission — the
  sandbox-clean, entitlement-minimal posture is chosen specifically to keep that
  door open.

### 9.2 Privacy & security

- **No outbound network requests.** The app declares the
  `com.apple.security.network.client` entitlement *solely* because `WKWebView`
  cannot run in the App Sandbox without it (§9.1); it makes **no actual network
  connections** — no telemetry, analytics, crash reporting, third-party SDKs,
  fonts, or CDNs, and the preview snippet is self-contained and loaded in-memory.
  The no-network behavior is verifiable with a network monitor.
- User input lives in memory only, **except** saved presets and settings, which
  are written to the local sandbox container **only when the user explicitly
  saves them** and are **never transmitted**. (This is the one deliberate
  divergence from the web edition's "nothing is ever stored" stance, and it is
  user-initiated and local-only.)
- The Advanced form accepts arbitrary HTML without sanitization; this is safe
  because the snippet is generated for the user's own use and the preview runs
  in an isolated WebKit context with navigation disabled and no same-origin
  access to the app.
- The app must remain fully functional with networking unavailable.

### 9.3 Performance

- Cold launch to interactive window: fast enough to feel instantaneous on
  supported hardware (target < ~500 ms on Apple silicon).
- Encoding + self-check of the longest reasonable input (Advanced, up to ~4 KB
  of HTML) completes well under one debounce interval and never blocks typing.

### 9.4 Accessibility

- Full **VoiceOver** support: every control has a meaningful accessibility label
  and value; the read-only snippet and preview are properly described.
- Complete **keyboard operability**: all functions reachable and operable
  without a mouse, with visible focus and logical focus order.
- Transient confirmations ("Copied") are announced via accessibility
  notifications.
- Color is never the sole carrier of meaning; contrast meets the platform's
  guidance in both light and dark appearance.
- Respects system settings (Reduce Motion, Increase Contrast) where applicable.

### 9.5 Internationalization & text

- **All user-facing text** is stored in a **String Catalog (`.xcstrings`)** —
  including working labels like "Saved values" — so wording changes and
  localization are content edits, not code edits. v1 ships English.
- Input and encoding are Unicode-correct end to end (code-point based, §7.2).

### 9.6 Appearance (light & dark)

- The app supports **Light and Dark** appearance automatically, using semantic
  system colors.
- The brand **dusty-sage accent (`#5E7C50`)** is used deliberately as the app's
  tint, with light/dark-correct variants defined in the asset catalog to
  preserve contrast.
- On macOS 26 Tahoe the standard controls render in the current system material
  treatment ("Liquid Glass"); on 14/15 they render in the standard appearance —
  no separate code path.

## 10. Mac-assed conventions (applied)

This app is held to the standard described in
[MAC-ASSED-MAC-APPS.md](MAC-ASSED-MAC-APPS.md). The concrete commitments for
this product:

- Single `Window` scene; no spurious New Window or tabbing; window frame
  restored across launches; **quit on last window close** (a focused
  single-window utility), with reopen-from-Dock recreating the window.
- A complete, conventional **menu bar** with working shortcuts (§6.9); standard
  Edit menu behaviors from native text controls.
- **Settings** via ⌘, (§6.10).
- **Native text-field hygiene:** smart quotes, smart dashes, and automatic text
  replacement are **disabled** in input fields (so emails/HTML are not mangled);
  spell-checking is off on code/HTML fields.
- **Light + Dark** appearance correctness (§9.6); deliberate brand accent.
- **Keyboard-first** operation and full VoiceOver support (§9.4).
- Native spacing, alignment, and control sizing — Mac metrics, not web metrics.
- Proper **About** box, app icon, and bundle metadata.
- Sandbox-clean, no network, notarization-ready (§9.1).

## 11. Visual & interaction design

- **Layout:** unified-toolbar, two-pane window (§6.1), built with native macOS
  spacing and control sizes. Forms use SwiftUI `Form`/grid alignment so labels
  and fields align on the Mac grid.
- **Typography:** the system font for UI; a monospaced system font
  (SF Mono / `ui-monospace`) for the snippet and decoded-source views.
- **Color:** neutral system grays plus the dusty-sage accent (`#5E7C50`) for the
  active mode segment, selection, and focus tint, with light/dark variants.
- **Motion:** minimal and respectful of Reduce Motion; the only "live" motion is
  the debounced snippet/preview update.
- **No** web chrome, no custom non-native widgets, no splash screen, no toasts
  beyond the inline "Copied" confirmation.

## 12. Acceptance criteria (v1)

The product is releasable when all of the following are true:

- [ ] Launches to a single, resizable window whose size/position restores across
      launches; opens to an empty form.
- [ ] Toolbar switches Basic/Advanced; ⌘1/⌘2 do the same.
- [ ] **Basic form:** valid input produces a snippet whose preview renders the
      expected `mailto:` link, rendered from the *actual* snippet.
- [ ] **Advanced form:** arbitrary HTML round-trips (preview shows what the raw
      HTML would render).
- [ ] **Live encoding:** the snippet updates ~400 ms after typing stops; invalid
      input shows the empty state with Copy disabled; the delay is adjustable in
      Settings.
- [ ] Encoded snippet contains **no `@`** and **no instance of the input email
      address**; the self-check (§7.3) passes for 50 random inputs in an
      automated test.
- [ ] Two consecutive encodes of identical input produce **different** snippets.
- [ ] **Copy** writes the snippet to the pasteboard; the "Copied" confirmation is
      announced to VoiceOver; the snippet/preview are read-only.
- [ ] **Saved values:** the user can save the current form state under a unique
      name, recall it (restoring mode + fields), rename/delete/reorder presets,
      and is prompted before replacing an existing name. Presets persist across
      launches.
- [ ] **Field hints:** each Basic field (and the Advanced field) exposes its hint
      via the `info.circle` affordance — help tag on hover, popover on
      click/keyboard — and to VoiceOver as accessibility help.
- [ ] **Clear Form:** a button and a keyboard-shortcut menu command clear the
      active form and reset the result, undoably, without confirmation, leaving
      the other mode's values and all saved presets intact; the action is
      disabled when the active form is already empty.
- [ ] The whole UI is operable from the keyboard with visible focus; VoiceOver
      describes every control.
- [ ] Renders correctly in **both Light and Dark** appearance.
- [ ] Smart quotes/dashes/auto-replacement are off in input fields.
- [ ] Runs with **App Sandbox enabled** and makes **no network requests**
      (verifiable with networking disabled and/or a network monitor).
- [ ] Ships as a **universal binary** (Apple silicon + Intel) and builds/runs on
      macOS 14, 15, and 26.

## 13. Out of scope for v1 (parking lot)

- Multiple encoder algorithms selectable by the user; exposed `max_passes` /
  `max_length` knobs.
- iOS/iPadOS/visionOS or Catalyst ports.
- Drag-and-drop of the snippet out of the app, or of an email into it; macOS
  Services integration.
- Exporting the snippet to a file (copy is sufficient).
- Localization beyond English (the String Catalog makes this a content task).
- Per-preset fallback-message overrides; richer preset metadata (tags, folders).
- iCloud sync of presets.
- A built-in Help book (beyond a basic Help menu entry).

## 14. Decisions & open questions

### Decided
- **Product name / verb:** **Obfuskoder** / **Obfuskode** (button-less now;
  "Obfuskode" survives as the product verb).
- **Output contract:** unchanged from the web edition — an HTML+JS web snippet.
- **Preview:** real `WKWebView` running the actual snippet; read-only.
- **Self-check:** JavaScriptCore round-trip + string checks (§7.3).
- **Encoding:** semi-live with a 400 ms default debounce, tunable in Settings;
  no Obfuskode button.
- **Persistence:** empty form by default; user-named presets via the Saved
  values menu; full-form-state snapshots; local-only.
- **Deployment target:** macOS 14; supported through macOS 26 Tahoe.
- **Distribution:** direct (notarized Developer ID) for v1, sandbox-clean to
  keep MAS open.
- **WKWebView entitlement:** the sandboxed preview requires
  `com.apple.security.network.client` to launch its WebContent process; it is
  declared, but the app makes no actual network requests (§9.1/§9.2). Resolved
  2026-06-06 after the preview rendered blank without it.
- **Appearance:** Light + Dark; dusty-sage (`#5E7C50`) accent.
- **License:** **MIT**. The README must acknowledge the original Hivelogic
  Enkoder by Dan Benjamin (and may note the 2009 Enkoder.app Mac edition).
- **Default fallback message:** *"Enable JavaScript to view email"*.
- **Architectures:** **universal binary (Apple silicon + Intel)** — firm, not a
  later decision (§5).
- **Field hints:** the four Basic hints (and the Advanced hint) are carried over
  from the web edition and presented via a macOS `info.circle` help affordance
  (hover help tag + click/keyboard popover), fully accessible (§6.3).
- **Clear Form:** present in both forms as a button plus an Edit-menu command
  (**⌘K**), undoable, per active form (§6.8).
- **License copyright holder:** **Michael A. Alderete** (matching the web
  edition).

### Still open
- **"Saved values" final label.** Working title; to be decided (candidates:
  "Presets", "Saved forms", "Saved entries"). Lives in the String Catalog.
- **Keyboard-shortcut conflict audit.** Verify the full app shortcut set
  (⌘K, ⇧⌘C, ⌘1, ⌘2, ⌘S, ⌘,) against standard macOS keyboard shortcuts to ensure
  none collide with system or conventional app bindings, before 1.0.
- **Min-OS opportunities.** Watch for cases where raising the target above
  macOS 14 (to 15 or 26) materially simplifies `WKWebView`, `Observation`, or
  SwiftUI usage; revisit before locking 1.0.
- **App icon.** To be designed.

## 15. References & acknowledgements

- The **Obfuskoder web edition** (`../Obfuskoder-JS/`) — the functional and
  visual reference; its `SPECIFICATION.md` defines the encoder contract this
  app inherits.
- **[MAC-ASSED-MAC-APPS.md](MAC-ASSED-MAC-APPS.md)** — the native-quality
  standard for this app.
- The original **[Hivelogic Enkoder](https://hivelogic.com/enkoder/)** by Dan
  Benjamin (now offline; see the Internet Archive), the inspiration for the
  whole project — including its 2009 **Enkoder.app** Mac desktop edition, a
  fitting precedent for this native version.
- Reference implementations consulted for the web edition (Hivelogic Ruby
  plugin; PHPEnkoder; Standalone PHPEnkoder). **No code from any of them ships
  in Obfuskoder**; the algorithm was written from scratch.
