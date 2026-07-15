# Undo / Redo Behavior — Improved Design Spec

- **Date:** 2026-07-14
- **Status:** Approved replacement behavior design; implementation requires a new plan
- **Feature:** Predictable, context-sensitive, Mac-native undo and redo
- **Supersedes:** `2026-07-10-undo-redo-design.md`

## 1. Goal and principles

Obfuskoder must make `Undo` and `Redo` behave like editing commands in a native
Mac app: they act on the current editing context, their menu titles predict the
next result, and every successful action makes its result visible.

The contract is defined in terms of user-observable actions, not timers,
snapshots, view wrappers, or undo-manager APIs. Architecture is recorded
separately in [ADR-0001](../../adr/0001-context-routed-model-owned-form-undo.md).

The key words **must**, **must not**, **should**, and **may** are normative.

## 2. Command presentation

- `Undo` and `Redo` must be the first commands in the **Edit** menu.
- Their standard shortcuts are **Command-Z** (`⌘Z`) and
  **Shift-Command-Z** (`⇧⌘Z`).
- When no action is available, the commands must read **Undo** and **Redo** and
  be disabled.
- When an action is available, each title must name the next result, such as
  **Undo Typing**, **Redo Clear Form**, or **Undo Apply “Personal”**.
- Obfuskoder must use the system-localized `Undo`/`Redo` prefix and provide a
  localized action name.
- The app must not add content-area Undo or Redo buttons. The Edit menu and
  standard shortcuts are the primary affordances.
- Menu titles and enabled state must update before the user next opens the Edit
  menu, including after a mode or key-window change.

## 3. Context routing

Undo and Redo must target the frontmost valid editing context. They must never
modify content hidden behind a modal sheet or in a different key window.

| Active context | Undo/Redo target |
|---|---|
| Main window, Basic mode | Basic form history |
| Main window, Advanced mode | Advanced form history |
| Main-window result or preview | Active mode's form history |
| Save Values sheet text field | That field's native text-edit history |
| Manage Saved Values rename field | That field's native text-edit history |
| Manage Saved Values sheet, outside a text edit | Saved-values management history, if provided (§12) |
| Settings fallback-message field | That field's native text-edit history |
| Modal sheet with no available action | Disabled; the form behind it is not changed |
| Settings window outside an editable text field | Disabled |
| Help window | Disabled |

Closing a sheet or returning the main window to key status must reveal the same
form history that was available before the other context took priority.

## 4. Two independent form histories

Form history is per mode, not global and not per field.

- The **Basic history** contains edits to Email address, Link text, Link title,
  and Subject, plus Basic Clear Form and application of Basic saved values.
- The **Advanced history** contains edits to the HTML field, plus Advanced
  Clear Form and application of Advanced saved values.
- The histories are independent and persist across mode switches.
- Switching modes is not undoable and must not clear either history or redo
  future.
- Switching modes must close the source mode's open text-edit group before the
  destination history becomes active.
- `Undo` must never switch modes or modify the inactive mode.
- If the active mode has no available action, `Undo` is disabled even when the
  inactive mode has history.
- Within a mode, field edits and form operations are ordered strictly by when
  their completed user actions occurred.

Example: edit Email, edit Subject, Clear Form. Three `⌘Z` presses restore the
Clear, then the Subject edit, then the Email edit. Focus follows each affected
field as defined in §8.

## 5. Undoable and non-undoable actions

### 5.1 Main-form actions

These actions are undoable:

- Text insertion and deletion in every Basic field and the Advanced HTML field.
- Cut, Paste, replacement of a selection, and text drag/drop.
- Accepting the Link text ghost completion with Tab.
- Clear Form.
- Apply Saved Values, for the destination mode's content only.

These actions are not form-history entries:

- Switching Basic/Advanced mode.
- Moving focus, the caret, or a selection.
- Live snippet regeneration, preview updates, or encoding failures.
- Copy Snippet or ordinary Copy.
- Show/Hide Decoded Source.
- Opening or closing menus, sheets, Settings, or Help.
- Saving current values under a name or explicitly replacing a saved value.
- Rejected input that never changes the model, such as a blocked `@`.

### 5.2 Other editing contexts

The exclusion of Settings and saved-value management from the *form* histories
must not disable ordinary text undo in their focused editable text fields. See
§12 for saved-value management operations themselves.

## 6. Deterministic text-edit grouping

Text undo must use semantic editing groups. It must not use an idle timer, and
focus loss must not collapse several groups into one field-session action.

- Consecutive character insertion at the same evolving insertion point is one
  **Typing** action. Spaces and line breaks remain part of that action.
- Consecutive backward deletion is one **Delete** action.
- Consecutive forward deletion is a separate **Delete** action.
- Switching between insertion and deletion ends the previous group.
- Moving the caret, changing the selection, or changing focus ends the current
  group but does not itself create history.
- Cut, Paste, selection replacement, drag/drop, and Link text completion each
  form their own single action.
- Clear Form, Apply Saved Values, mode switching, Undo, and Redo end any open
  text group before they proceed.
- A pause in typing, regardless of length, does not by itself end a group.
- Leaving a field preserves all groups already formed in that field; it does
  not merge them into one action.
- A group whose final content equals its initial content records nothing.

Selection movement after an Undo does not invalidate Redo. The first subsequent
content-changing action does.

## 7. Action-specific behavior

### 7.1 Ordinary text actions

Each text action must identify its field and preserve both its before-state and
after-state, including text and caret/selection. The Advanced editor must also
preserve enough scroll state to reveal the affected range.

- Undo restores the before-state.
- Redo restores the after-state.
- The affected field becomes first responder and reveals the restored caret or
  selection.
- Undo must not select the entire field unless that was the recorded selection.

Recommended action names are **Typing**, **Delete**, **Cut**, **Paste**, and
**Replace**.

### 7.2 Link text ghost completion

The ghost value is presentation, not stored Link text.

- Changes to Email that change the ghost value record only the Email edit.
- Merely displaying or changing the ghost value records nothing.
- Accepting it with Tab is one action named **Complete Link Text**.
- Undo restores Link text to empty, causing the current ghost value to appear.
- Redo restores the accepted literal value.

### 7.3 Clear Form

Clear Form is one atomic action.

- It closes any open text group first.
- It clears only the active mode.
- When the active form is already empty, it is a no-op: it creates no history
  and does not invalidate Redo.
- Undo restores every field in that mode in one step.
- Redo clears every field in that mode in one step.
- The inactive mode is never changed.
- Undo restores the most recently focused input field and its selection from
  before Clear. If no input field is known, the fallback is Email address in
  Basic mode or the HTML editor in Advanced mode.
- Redo keeps focus in the same logical field and places a valid caret in its
  empty content.
- Because Clear is immediately undoable, it requires no confirmation alert.

Action name: **Clear Form**.

### 7.4 Apply Saved Values

Apply Saved Values is one atomic content action on the preset's destination
mode.

- It closes the source mode's open text group before applying.
- It switches to the preset's mode immediately. That mode switch is not undone.
- It records the destination mode's contents before and after application, not
  a whole-form state that can overwrite the source mode.
- Undo remains in the destination mode and restores that mode's prior content.
- Redo remains in the destination mode and reapplies the preset.
- The source mode's content and history are never changed by this action.
- If the preset content is identical to the destination mode's existing
  content, no history is recorded and Redo is not invalidated, even if applying
  the preset switched modes.
- A real Apply invalidates only the destination mode's redo future.
- Undo restores the destination mode's prior input focus and selection when
  known, otherwise its first field.
- Apply and Redo focus the first field of the loaded mode without selecting all
  content.

The action name should include the saved value's name when available, for
example **Apply “Personal”**.

## 8. Focus, selection, visibility, and feedback

Every successful main-form Undo or Redo must make its result evident.

- A text action focuses its affected field and restores its recorded
  caret/selection.
- Clear uses the focus behavior in §7.3.
- Apply uses the focus behavior in §7.4.
- Advanced content must scroll enough to reveal the restored caret or selection.
- Basic content must scroll into view if future layout changes make a restored
  field offscreen.
- Focus must never move to the generated result or preview as an undo side
  effect.
- The app must not display a toast or confirmation for routine Undo/Redo.
- With VoiceOver active, the focused field and changed value should provide the
  primary feedback. A concise accessibility announcement may be used for a
  whole-form action only when focus/value feedback does not make its result
  clear; duplicate announcements should be avoided.

## 9. Redo invalidation and no-ops

A new content-changing action after Undo discards only the redo future belonging
to that action's mode or context.

The following must not invalidate Redo:

- Mode switching.
- Focus, caret, or selection movement.
- Copy, preview/result regeneration, or disclosure changes.
- Opening or dismissing auxiliary UI.
- Rejected input.
- Clear on an already-empty form.
- Applying content identical to the destination mode's current content.
- Any edit group that returns to its starting content before it closes.

Undo or Redo invoked at the bottom of its available history must be disabled;
direct invocation through any alternate path must be a harmless no-op and must
not crash.

## 10. Menu action vocabulary

Use short localized action names:

| Action | Example menu title |
|---|---|
| Continuous insertion | Undo Typing |
| Continuous deletion | Undo Delete |
| Cut | Undo Cut |
| Paste | Undo Paste |
| Selection replacement | Undo Replace |
| Accept Link text ghost | Undo Complete Link Text |
| Clear active form | Undo Clear Form |
| Apply a named saved value | Undo Apply “Personal” |

The same action name must produce the symmetric Redo title.

## 11. History lifetime and depth

- Both form histories start empty at app launch.
- They persist until the app process ends and are not serialized.
- There is no artificial application-level depth cap.
- Saving a preset is not a save boundary for form history.
- Closing a temporary sheet does not clear form history.

## 12. Saved values and Settings

### 12.1 Focused text editing

Native text Undo/Redo must remain available while editing a name in Save Values
or Manage Saved Values, and while editing the Settings fallback message. These
local text histories take priority over form history.

### 12.2 Persistent saved-value operations

For a fully Mac-optimized Manage Saved Values sheet, Rename, Delete, and Reorder
should share a separate sheet-scoped history:

- **Rename Saved Value** restores the prior committed name.
- **Delete Saved Value** restores the deleted item, its payload, and its list
  position.
- **Reorder Saved Values** restores the prior order as one action per completed
  drag or Move Up/Down command.

This history must never mix with Basic or Advanced history. If immediate Delete
remains non-undoable, it must instead require confirmation; undoable immediate
Delete is preferred.

Saving a new named value and explicitly confirming replacement of an existing
one remain outside the form histories. Settings slider and picker changes are
committed preferences and are not application-level undo actions.

## 13. Non-goals

- Persisting history across launches.
- A global chronology spanning Basic, Advanced, sheets, and Settings.
- Undoing mode switches, copy operations, output generation, or view state.
- Defining undo-manager classes, snapshot representation, or SwiftUI/AppKit
  wiring in this behavior document.

## 14. Verification gate

This feature is not complete based on model unit tests alone. The complete
[Undo/Redo Manual Test Plan](../../MANUAL-TEST-UNDO-REDO.md) must pass in a real
app build on every supported macOS version, including keyboard routing, menu
validation, focus/selection restoration, mode isolation, auxiliary-window
contexts, redo invalidation, and undoing past the bottom without a crash.

## 15. Related records

- [ADR-0001 — Context-routed, model-owned form undo](../../adr/0001-context-routed-model-owned-form-undo.md)
- [Undo-routing spike findings](../../undo-routing-findings.md)
- [Undo/Redo manual test plan](../../MANUAL-TEST-UNDO-REDO.md)
- [Superseded 2026-07-10 behavior spec](2026-07-10-undo-redo-design.md)
- [Superseded 2026-07-10 implementation plan](../plans/2026-07-10-undo-redo.md)

## 16. Platform references

- [Apple Human Interface Guidelines — Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo/)
- [Apple Human Interface Guidelines — Edit menus](https://developer.apple.com/design/human-interface-guidelines/edit-menus)
- [Apple Human Interface Guidelines — Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection)
- [Apple Undo Architecture — Setting Action Names](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/UndoArchitecture/Articles/SettingUndoNames.html)
- [Apple AppKit — `NSTextView.breakUndoCoalescing()`](https://developer.apple.com/documentation/appkit/nstextview/breakundocoalescing())
