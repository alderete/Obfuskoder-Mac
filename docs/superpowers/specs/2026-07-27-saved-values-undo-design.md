# Saved Values Undo/Redo — Design Spec

- **Date:** 2026-07-27
- **Status:** Approved design
- **Related:** `docs/MANUAL-TEST-UNDO-REDO.md` §10.4 (anticipates this);
  form-undo architecture `docs/adr/0001-context-routed-model-owned-form-undo.md`

## Motivation

Deleting a saved value in the **Manage Saved Values** panel is a destructive
action with **no confirmation dialog**. Undo is the safety net for an accidental
delete — that is the primary goal. Reordering the list should also be undoable.
This is a small, self-contained undo domain, **separate** from the two per-mode
form (Basic/Advanced) undo stacks.

## Scope

**In scope:**
- Undo/redo of **deleting** a saved value (restored at its original position).
- Undo/redo of **reordering** the list (drag gripper and Move Up / Move Down).

**Out of scope (explicit):**
- Undoing **creation** of a saved value — creation happens in the Save sheet,
  not Manage; a just-created value is trivially deleted instead.
- Undoing **value/name changes** — renames keep using the field editor's
  **native** text undo (already working); this stack never touches rename.

**Lifetime:** per Manage-panel session. The stack is created when the panel
opens and cleared when it closes. Undo/redo is reachable **only while the panel
is open** — the only coherent context for it, given the app's context-routed
⌘Z (the main window's ⌘Z belongs to the form undo). No cross-launch
persistence.

## Mechanism — granular inverse operations

Each undoable action registers a **specific inverse** on a
`Foundation.UndoManager`, so it composes correctly with renames (which mutate
the same array via the separate native-undo path) in the same session.
Whole-array snapshots were rejected: undoing a delete would clobber a rename
made afterward.

- **Delete "X":** capture the preset value and its list index. Undo re-inserts
  that preset at that index; redo deletes it by id.
- **Reorder:** capture the list's **id-order** before and after. Undo restores
  the previous id-order (mapping by id, so current names/payloads are
  preserved); redo re-applies.

## Components

### `SavedValuesUndo` (ObfuskoderKit, `@MainActor`)

Owns a `Foundation.UndoManager` (`groupsByEvent = false`; each action is one
discrete step). Wraps the store's delete/reorder to record inverses and exposes
undo state. Unit-tested like `FormActionRecorder`.

Interface (signatures):
- `init(store: PresetStore, undoManager: UndoManager = UndoManager())`
- `func delete(id: UUID, actionName: String) throws` — deletes via the store
  and registers the re-insert inverse; sets the UndoManager's action name to
  `actionName`.
- `func move(fromOffsets: IndexSet, toOffset: Int, actionName: String)` —
  reorders and registers the id-order inverse.
- `var canUndo: Bool` / `var canRedo: Bool`
- `var undoMenuItemTitle: String` / `var redoMenuItemTitle: String` — delegate
  to the UndoManager, which composes the localized "Undo &lt;name&gt;".
- `func undo()` / `func redo()`
- `func reset()` — remove all actions (called on panel close).

The localized action name ("Delete \"Personal\"" / "Move \"Personal\"") is
supplied by the **app layer**, keeping ObfuskoderKit free of UI strings.

### `PresetStore` additions (ObfuskoderKit)
- `func insert(_ preset: Preset, at index: Int)` — re-inserts a preset (clamping
  the index to `0...presets.count`), persists. Used by delete-undo. Does **not**
  enforce name-uniqueness (a restore); a duplicate name — only possible if a
  rename freed/took it mid-session — is allowed.
- `func setOrder(_ ids: [UUID])` — reorders `presets` to the given id sequence
  (ids not present are ignored; any present-but-unlisted ids are appended in
  their current relative order), persists. Used by reorder-undo/redo.

### Manage panel (`ManagePresetsSheet`) wiring
- Receives/owns a `SavedValuesUndo` for the current session and routes its
  delete and Move Up/Down/drag actions through it (instead of calling
  `PresetStore` directly). Rename is unchanged (native field undo).
- On appear: registers the `SavedValuesUndo` with `UndoRouter`. On disappear:
  clears the registration and calls `reset()`.

### `UndoRouter` routing
- Add a `savedValuesUndo` context. When the Manage panel is the active context
  (its sheet is key/attached) **and no name field is first responder**, ⌘Z /
  ⇧⌘Z and the Edit-menu Undo/Redo target `SavedValuesUndo`; the menu shows its
  titles and enabled state.
- When a name field **is** focused, native text undo wins (unchanged) — renames
  undo in-field exactly as today.
- Menu state refreshes via the router's existing `tick` mechanism, observing the
  saved-values UndoManager's undo/redo/close-group notifications.

## Row-restore animation

When undo re-inserts a deleted preset, the re-appearing row **animates into
place — squeezing into its space**: an insertion transition where the row grows
from collapsed height with a fade while the rows below make room. Undoing a
reorder animates rows to their restored positions using the panel's existing
reorder animation. Both honor **Reduce Motion** (instant, no animation, when
enabled), consistent with the mode-switcher lozenge. Implementation: an implicit
`.animation(reduceMotion ? nil : .default, value: <presets id-list>)` on the
list, plus a `.transition` on the row.

## Edge cases
- Undo re-insert clamps the index to current bounds.
- Duplicate-name collision on re-insert is allowed (a restore is not blocked by
  uniqueness).
- Closing the panel clears the stack (per-session lifetime).
- Empty-stack undo/redo is a harmless no-op.
- LIFO ordering (Foundation.UndoManager) keeps interleaved delete/reorder undo
  correct.

## Testing

**ObfuskoderKit unit tests (`SavedValuesUndoTests`):**
- Delete then undo restores the preset at its original index; redo deletes again.
- Reorder then undo restores the previous order; redo re-applies.
- A rename between a delete and its undo is preserved (delete-undo does not
  revert the rename).
- Re-insert index clamps when the list shrank.
- Empty-stack undo/redo no-ops; `canUndo`/`canRedo` correctness.

**Manual (add to `docs/MANUAL-TEST-UNDO-REDO.md` §10.4):**
- In the Manage panel: delete a preset → ⌘Z restores it (animated, squeezing in)
  at its position; ⇧⌘Z deletes again.
- Reorder (drag and Move Up/Down) → ⌘Z restores the order.
- Edit-menu titles show **Undo Delete "Name"** / **Undo Move "Name"** and
  symmetric Redo; disabled when the stack is empty.
- While editing a name field, ⌘Z undoes the text edit (native), not the
  delete/reorder.
- Closing and reopening the panel starts with an empty stack.
- With Reduce Motion on, restores are instant (no animation).
