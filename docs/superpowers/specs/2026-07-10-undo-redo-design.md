# Undo / Redo Behavior — Design Spec

- **Date:** 2026-07-10
- **Status:** Superseded 2026-07-14; retained as a historical record
- **Feature:** Coherent undo/redo for the input form (the FIX-3 redo, done right)

> **Do not use this document as the current behavior contract.** It was replaced
> by [Undo / Redo Behavior — Improved Design Spec](2026-07-14-undo-redo-design-improved.md).
> In particular, its word-level/edit-burst language, focus rules, and blanket
> exclusion of auxiliary text-editing contexts are no longer normative. The
> routing investigation remains valid and is captured in
> [ADR-0001](../../adr/0001-context-routed-model-owned-form-undo.md).

## 1. Goal & framing

Give the input form **coherent, native-feeling undo/redo**. The design is
deliberately **standard macOS text-undo behavior with a few clarifications** —
not a bespoke system. The earlier attempt (FIX-3) crashed and misbehaved because
two undo managers fought each other (see §8); this spec defines the *behavior* we
want so the implementation can proceed without re-deriving intent. Architecture
is the implementation plan's job — §8 pins the one hard constraint that keeps the
behavior achievable and prevents repeating the crash.

## 2. Scope

**In scope — form content:**
- Text edits in the Basic fields (Email, Link text, Link title, Subject).
- Text edits in the Advanced field (HTML).
- **Clear Form**.
- **Apply Saved Values** (loading a preset), content only.

**Out of scope (keep their existing affordances, no `⌘Z`):**
- **Mode switching** (Basic ↔ Advanced) — explicitly *not* undoable.
- **Presets pane** management — Save Current Values, Rename, Delete, Reorder.
- **Settings pane** — Encoding delay, Fallback message, Update-check frequency.

## 3. Model: two mode-scoped stacks

Undo history is **per mode**, not global and not per-field:

- **Basic stack:** the four Basic fields + Clear Form (while in Basic) + Apply
  (of a Basic preset).
- **Advanced stack:** the HTML field + Clear Form (while in Advanced) + Apply
  (of an Advanced preset).

The two stacks are **independent** and **each persists across mode switches**.
Switching mode simply changes which stack `⌘Z`/`⇧⌘Z` targets; **undo never
crosses modes**. (This is what eliminates the "undo across a mode switch"
ambiguity entirely.) Within a mode, undo is **most-recent-first across that
mode's fields and operations** — e.g. edit Email, edit Subject, Clear Form →
`⌘Z` undoes the Clear, then the Subject edit, then the Email edit.

## 4. Per-scenario behavior

| Trigger | Undo does | Redo does | Notes |
|---|---|---|---|
| **Field text edit** | Reverts the last word-level change **and moves focus to that field**, revealing the change | Re-applies it | Native text granularity; ordered most-recent-first across the mode's fields |
| **Clear Form** | Restores all cleared fields in **one step** | Clears them again | Focus returns to the field active before Clear, else the first field (Email / HTML) |
| **Apply Saved Values** | Restores the target mode's **prior contents** in one step | Re-applies the preset's contents | The mode-switch part is *not* undone — you stay in the loaded mode; focus → first field |
| **Mode switch** | — (not undoable, not recorded) | — | Each mode's history stays intact |

## 5. Cross-cutting defaults (native macOS)

- **Granularity:** the model records a snapshot per **edit-burst** — a new undo
  step when typing pauses or focus leaves the field — approximating word/phrase
  level, not per-keystroke. (The fields' native per-cell undo can't be unified
  with the form operations; the model owns undo instead — see §8 and
  `docs/undo-routing-findings.md`.)
- **Redo:** symmetric `⇧⌘Z`.
- **History lifetime:** session-only; **not persisted** across launches; no
  artificial depth cap (rely on `NSUndoManager` defaults).
- **Redo invalidation:** making a new edit after undoing drops the redo stack
  (native).

## 6. Edit menu

The **Edit ▸ Undo / Redo** items reflect the **active mode's** stack:
- Labeled with the pending action — "Undo Clear Form", "Undo Typing",
  "Redo Apply Saved Values", etc. (via `NSUndoManager.setActionName`).
- **Disabled** when the active mode's stack has nothing to undo/redo.
- Switching mode updates the labels/enablement to that mode's stack; each mode's
  history is preserved (so switching back restores its Undo/Redo).

## 7. Edge cases

- **Clear Form on an already-empty active form:** no-op; nothing is recorded
  (matches today's `guard !form.activeIsEmpty`).
- **Undo of Clear Form** restores every cleared field of the active mode as a
  single undo step (whole-mode snapshot), not one step per field.
- **Undo of Apply Saved Values** restores the target mode's prior contents as a
  single step; **redo** re-applies the preset's contents. If Apply switched mode,
  that switch already happened and is not reversed by undo.
- **New edit after undo** drops the redo stack for that mode (native).
- **Focus-follows-undo** applies to every undo/redo: the affected field becomes
  first responder and reveals (selects/scrolls to) the change.

## 8. Implementation constraint (hard — do not repeat FIX-3)

**Resolved mechanism (spike 2026-07-10 — see `docs/undo-routing-findings.md`):**
**model-owned snapshot undo.** `NSTextField`'s native editing-undo lives in a
private `NSCellUndoManager` that can't be redirected; `NSTextView`'s delegate
*can* route, but we don't rely on it. Instead the model records `FormState`
snapshots on a per-mode `NSUndoManager` for text edits (coalesced per edit-burst)
+ Clear + Apply. `NSTextView.allowsUndo = false`; the field editors' native undo
is bypassed by custom `⌘Z`/`⇧⌘Z` Edit-menu commands that call the model manager
directly (menu key-equivalents are checked before the responder chain, so the
field editor never handles them). This is what also makes `⌘Z` work at all.

The FIX-3 attempt crashed and produced the "Clear gets skipped by undo" bug
because it mixed **two uncoordinated undo managers**: each text field's default
**AppKit field-editor `NSUndoManager`** (via `allowsUndo = true` in
`MacTextField` / `MacTextEditor`) *and* SwiftUI's **`@Environment(\.undoManager)`**
(used by `AppModel.clearActiveForm` / `restoreForm` in `ContentView`). `⌘Z`
routed to whichever the responder chain picked, so the two stacks diverged.

**Therefore, non-negotiable for this design:** within a mode, the text fields
**and** the form operations (Clear, Apply) must register into **one shared,
mode-scoped `NSUndoManager`**, and the text views must use *that* manager rather
than their default field-editor manager. Whether the implementation uses one
`NSUndoManager` per mode (swapped as the active manager on mode switch) or a
model-owned undo coordinator is the plan's decision — but the fields and the
form ops MUST live on the same manager, or the behavior in §3–§4 is impossible.

Good news: the current `AppModel.clearActiveForm(undoManager:)` /
`restoreForm(_:undoManager:)` are already **whole-`FormState` snapshot/restore**
registrations — the right shape. What's missing is (a) making them (and a new
undoable `apply(_:)`) target the *mode-scoped* manager, (b) routing the text
fields to that same manager, and (c) focus-follows-undo.

## 9. Non-goals

- No undo persistence across app launches.
- No undo for mode switching, presets, or settings.
- No cross-mode (global) undo history.

## 10. For the implementation plan

- Choose the architecture (per-mode `NSUndoManager` vs. a model-owned undo
  coordinator) — both can satisfy §3–§8; pick the simpler one that wires the
  AppKit text views to the mode manager cleanly.
- Make `AppModel.apply(_:)` undoable (target-mode snapshot), mirroring the
  existing `clearActiveForm`/`restoreForm` pattern.
- Implement focus-follows-undo (the undo action moves first responder to the
  affected field and reveals the change).
- **Testing:** the snapshot/restore logic is unit-testable; the undo-manager
  wiring + focus behavior is runtime-only and MUST be exercised with live
  `⌘Z`/`⇧⌘Z` testing across both modes — that live gap is exactly what let the
  FIX-3 crash ship. Cover the interleaving (edit → edit → Clear → multiple ⌘Z),
  cross-field focus, Apply undo, and mode-switch stack isolation.
