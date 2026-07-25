# Undo Routing — Spike Findings (Task 1)

**Date:** 2026-07-10 · **Branch:** `undo-redo`

> **Current status (2026-07-14):** The measured routing findings and the choice
> of model-owned, per-mode form undo remain accepted. The provisional
> pause/edit-session granularity chosen during the spike has been superseded by
> the deterministic semantic grouping in the
> [improved behavior spec](superpowers/specs/2026-07-14-undo-redo-design-improved.md).
> See [ADR-0001](adr/0001-context-routed-model-owned-form-undo.md) for the durable
> architecture decision.

## Question

Can the editing-undo of the form's text views (`MacTextField`/`NSTextField` and
`MacTextEditor`/`NSTextView`) be routed to a **model-owned `NSUndoManager`**, so
field edits and form operations (Clear, Apply) can share one mode-scoped stack?

## Method

Temporary wiring pointed both field types at a shared `UndoSpike.manager`:
`NSTextView` via the `undoManager(for:)` delegate; `NSTextField` via overriding
`undoManager` on the `NSTextField` subclass. A live diagnostic (`Spike ▸ Report
undo state`) reported the focused field editor's `undoManager` identity and
`canUndo`, plus the window's.

## Findings (measured live on macOS 26)

**`NSTextView` (Advanced field): routing WORKS.**
- `editor.undoManager === spike? true`, `UndoSpike.manager canUndo=true`.
- The `undoManager(for view:)` delegate is honored; the text view registers its
  editing-undo on the manager we provide. (Note: making the *visible* text revert
  also requires syncing the SwiftUI `text` binding after undo — the representable
  otherwise re-applies the stale value. A fixable detail, not a routing failure.)

**`NSTextField` (Basic fields): routing FAILS.**
- `editor.undoManager: NSCellUndoManager canUndo=true`, `=== spike? false`.
- Editing-undo goes to a **private `NSCellUndoManager`** chosen internally by the
  cell/field-editor machinery. It ignores the responder-chain `undoManager`
  override and there is no delegate hook for it. It cannot be cleanly redirected.

**Menu disconnect (explains today's "⌘Z does nothing"):**
- The window's undo manager is a separate, empty `NSUndoManager`
  (`canUndo=false`). SwiftUI's default Edit ▸ Undo targets that (or the empty
  environment manager), never the field editor's `NSCellUndoManager` — so `⌘Z`
  currently does nothing while editing a field.

## Decision (user)

**Model-owned snapshot undo**, uniform across both modes. We do NOT rely on the
fields' native undo:
- The model owns one `NSUndoManager` per mode and registers **`FormState`
  snapshots** for text edits (coalesced) + Clear + Apply on the active one.
- `NSTextView`: set `allowsUndo = false` (don't double-register).
- `NSTextField`: its `NSCellUndoManager` can't be disabled but is **bypassed** —
  our own Edit ▸ Undo/Redo commands (`⌘Z`/`⇧⌘Z`) call `model.activeUndoManager`
  directly. Menu key-equivalents are checked before the responder chain, so the
  field editor's native undo is never invoked.
- **Granularity at the time of the spike:** coalesced edit-bursts (a step per
  typing pause / focus change), not literal native per-keystroke/word. This was
  later found to be an implementation-shaped and unpredictable product rule; it
  is historical rather than normative. The 2026-07-14 improved spec replaces it
  with semantic action boundaries and no idle timer.

## Why not the alternatives

- *Custom field editor to force NSTextField onto our manager:* fights AppKit's
  private per-cell undo inside a SwiftUI window — fragile, uncertain, highest risk
  (the FIX-3 failure mode).
- *Rebuild Basic fields as NSTextViews:* would work natively, but re-implements
  the bezel styling, `@`-blocking formatter, and Tab ghost-text completion — too
  much collateral change for the granularity gain.
