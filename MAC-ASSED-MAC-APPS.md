# What Makes a "Mac-assed Mac App"

A reference for [Obfuskoder for macOS](SPECIFICATION.md). This captures the
standard we hold the app to, so "be a real Mac app" means something concrete and
checkable rather than a vibe.

## The phrase

The term comes from **John Gruber** (Daring Fireball, 2020), riffing on a
developer's plea for a *"Mac-ass Mac app."* Gruber's framing:

> *"A Mac-assed Mac app."*

The idea: a great Mac app isn't merely an app that *runs* on a Mac. It's an app
that is **of** the Mac — one that embraces the platform's conventions, idioms,
and human-interface expectations instead of importing patterns from the web,
from iOS, or from a cross-platform toolkit that renders the same gray rectangle
on every OS. It looks, feels, and behaves the way a Mac user expects, because it
is built with the grain of the platform, not against it.

A Mac-assed Mac app is the opposite of:

- A **website in a window** (a web view pretending to be an app).
- An **iPad app stretched** onto the desktop.
- An **Electron / cross-platform** app that ignores native menus, keyboard
  conventions, appearance, and spacing in the name of one codebase.

The bar is *not* visual novelty. It's **fluency in the platform's existing
vocabulary**. A Mac-assed app is often "boring" in the best way: nothing
surprises the user, everything is where they expect, every habit they've built
over years of Mac use just works.

## Principles

1. **Native by default.** Use the system's own controls, layout metrics, fonts,
   and materials. Reach for custom UI only when the platform genuinely lacks
   something — and make the custom thing behave like a native one.
2. **The menu bar is the app.** A complete, conventional menu bar with sensible
   organization and keyboard shortcuts is table stakes, not an afterthought.
3. **Keyboard-first.** Every meaningful action is reachable and operable from
   the keyboard, with standard shortcuts and visible focus. The mouse is
   optional, never mandatory.
4. **Respect the standard behaviors you get for free.** Copy/paste, undo/redo,
   select-all, drag-and-drop, services, window restoration, full-keyboard
   access — don't break them, and don't reinvent them.
5. **Appearance correctness.** Light and Dark mode both look right. Use semantic
   colors. Honor the user's accent, contrast, motion, and transparency settings.
   Adopt the current design language (e.g., Tahoe's materials) by using standard
   controls.
6. **Native metrics.** Mac spacing, alignment, and control sizes — not web
   padding or touch-sized iOS targets. Things line up on the Mac grid.
7. **Conventional windows & state.** Windows behave predictably; size and
   position are restored; the document/utility model matches user expectations.
8. **Settings in the right place.** A real Settings window opened with ⌘, — not
   a gear buried in the content.
9. **Text behaves like Mac text.** Standard editing, find, spelling/substitution
   controls — and crucially, *don't* mangle user input (smart quotes turning
   `"` into `"`, dashes, auto-replace) where it matters.
10. **Quiet, system-consistent feedback.** Use the platform's idioms (sheets,
    inline validation, subtle confirmations) instead of web-style toasts or
    modal dialog spam.
11. **First-class accessibility.** VoiceOver, full keyboard access, contrast, and
    Reduce Motion are part of "works," not a later add-on.
12. **Good platform citizen.** Sandbox where reasonable, sign and notarize,
    request only the entitlements you actually need, and don't phone home.

## The checklist (how Obfuskoder is held to it)

A pass/fail list the app should satisfy. Items map to the
[specification](SPECIFICATION.md).

### Windows & lifecycle
- [ ] Single, predictable `Window` scene; no spurious "New Window" / tabbing.
- [ ] Window size and position restored across launches.
- [ ] Sensible minimum window size; resizes gracefully.
- [ ] Clear, conventional quit/close behavior; reopen from Dock works.

### Menus & keyboard
- [ ] Complete menu bar: app, File, Edit, View, Window, Help.
- [ ] Standard Edit menu works (Undo/Redo, Cut/Copy/Paste, Select All).
- [ ] App-specific commands have discoverable, conventional shortcuts.
- [ ] Settings opens with ⌘,.
- [ ] Entire app operable from the keyboard; visible focus; logical focus order.

### Appearance & layout
- [ ] Correct in both Light and Dark appearance; semantic colors.
- [ ] Native spacing, alignment, and control sizing (Mac metrics).
- [ ] Adopts the current system material/design language via standard controls.
- [ ] Deliberate, contrast-correct brand accent (does not fight the system).

### Text & input
- [ ] Smart quotes, smart dashes, and auto text-replacement disabled where they
      would corrupt input (emails, code/HTML).
- [ ] Spell-checking off on code/HTML fields.
- [ ] Standard text selection/editing behaviors intact.

### Feedback & interaction
- [ ] Validation is inline and non-modal; no alert spam.
- [ ] Confirmations are quiet and system-consistent (no web-style toasts).
- [ ] Sheets used for modal sub-tasks (naming/managing presets).

### Accessibility
- [ ] Full VoiceOver labels/values, including read-only snippet and preview.
- [ ] Confirmations announced to assistive tech.
- [ ] Honors Reduce Motion / Increase Contrast.

### Platform citizenship
- [ ] App Sandbox enabled; minimal entitlements.
- [ ] No network access; no telemetry; no third-party SDKs.
- [ ] Signed and notarization-ready.
- [ ] User data stored locally, only when the user asks, never transmitted.

## Why it matters for a tool this small

Obfuskoder is a simple utility — which is exactly why the standard is worth
stating. Small apps are where "it's just a quick thing" becomes the excuse for a
web view in a window. Holding even a one-window tool to the Mac-assed bar is the
point: it's the difference between software that merely runs on a Mac and
software that belongs there.

## Further reading

- John Gruber, *"A Mac-assed Mac app"* — Daring Fireball (2020).
- Apple **Human Interface Guidelines**, macOS — the canonical source for the
  conventions summarized above.
