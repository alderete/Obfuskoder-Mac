# ADR-0001: Context-Routed, Model-Owned Form Undo

- **Date:** 2026-07-14
- **Status:** Accepted
- **Decision owners:** Obfuskoder project
- **Related behavior spec:**
  [Undo / Redo Behavior — Improved Design Spec](../superpowers/specs/2026-07-14-undo-redo-design-improved.md)

## Context

Obfuskoder edits two persistent form buffers in one main window:

- Basic: four `NSTextField`-backed fields.
- Advanced: one `NSTextView`-backed HTML editor.

The same form histories must also contain atomic model operations such as Clear
Form and Apply Saved Values. Basic and Advanced histories are independent, and
Undo must follow the active mode while the main form is the active editing
context.

The original implementation used SwiftUI's environment undo manager for
whole-form changes while AppKit text editors registered their own text actions.
The managers were not reliably the same. The mixed stacks produced stale text
actions, wrong ordering (Clear could be skipped), and a crash when undoing past
the expected stack boundary. Model-only tests did not reproduce the live
responder-chain behavior.

The 2026-07-10 live spike established that:

- `NSTextView` can route editing undo through its delegate.
- `NSTextField` editing uses a private `NSCellUndoManager` that did not honor the
  attempted model-manager routing.
- The window/environment manager was separate from the focused Basic field
  editor's manager.
- A single native AppKit text-undo stack therefore could not be cleanly shared
  by both field types and the form operations.

The spike is recorded in
[Undo Routing — Spike Findings](../undo-routing-findings.md).

## Decision

### 1. The main form owns its undo domain

The app model owns one form-history coordinator for Basic and one for Advanced.
Each coordinator is responsible for every undoable action in that mode:

- semantic text-edit actions;
- Clear Form;
- Apply Saved Values for that destination mode.

No main-form action may register on SwiftUI's environment undo manager or a
field editor's private manager.

### 2. Main-form commands bypass native field-editor undo

While the main form is the active editing context, the Edit-menu Undo/Redo
commands and their key equivalents invoke the active mode's model-owned
coordinator directly. Advanced native text undo is disabled; Basic private cell
undo is not used by the app commands.

The coordinator records enough before/after state to satisfy the behavior spec,
including field identity and caret/selection. A whole-form `FormState` snapshot
alone is insufficient for focus and selection restoration.

### 3. Command routing is context-sensitive

The application command layer determines the key window, active sheet, and
focused editor before choosing a target.

- Main form or its read-only result area: use the active mode coordinator.
- Focused editable field in Save Values, Manage Saved Values, or Settings: allow
  that editor's native text undo to take priority.
- Modal or auxiliary context with no applicable action: disable Undo/Redo; never
  reach behind it to mutate the main form.
- A future saved-values management history is separate from form history.

Context routing is part of the architecture because a single app-global command
target cannot meet the Mac behavior contract.

### 4. Editing groups are semantic, not timer-based

The model coordinator creates action boundaries from editing semantics defined
by the behavior spec: insertion/deletion transitions, caret or selection moves,
focus changes, discrete editing commands, form operations, and mode changes.

Elapsed idle time is not an action boundary. Ending a field-editing session does
not collapse previously formed groups.

### 5. Mode isolation is enforced at the content-slice boundary

An action recorded on a mode's coordinator restores only that mode's content.
It must not restore a whole `FormState` in a way that can overwrite the inactive
mode or reverse a mode switch. Applying a preset records on the destination
mode's coordinator after determining whether its destination content actually
changed.

### 6. Runtime verification is a release gate

Unit tests cover history ordering and before/after restoration, but they are not
sufficient evidence for command routing, menu validation, first-responder
movement, selection, or scrolling. The dedicated manual test plan must pass in a
real build before the feature is considered complete.

## Consequences

### Positive

- Basic and Advanced behave consistently despite different AppKit text systems.
- Field edits and form-wide actions have one authoritative order per mode.
- Form restoration cannot replay stale native character-range actions.
- Menu state, focus, selection, and no-op rules can be specified and tested from
  one model-owned action stream.
- Auxiliary text fields retain familiar native Mac text undo instead of having
  the main form intercept their shortcuts.

### Costs and risks

- The app must reproduce the required subset of AppKit text grouping and
  selection restoration rather than receiving it for free.
- Command validation must observe key-window and first-responder changes, not
  only form-mode changes.
- Snapshot-only unit tests can give false confidence; live tests remain
  mandatory.
- Future editable contexts require an explicit routing decision.

## Rejected alternatives

### One shared window/environment undo manager

Rejected because the live field editors did not reliably use it. The previous
mixed implementation misordered actions and crashed.

### Native text undo for fields plus a separate form-operations stack

Rejected because `⌘Z` would need to guess between divergent histories. Clear and
Apply could again be skipped by stale field-editor actions.

### Rebuilding every Basic field as an `NSTextView`

Rejected as disproportionate collateral change. It would require recreating
single-line field behavior, bezel styling, formatting, and Link text completion
only to gain routable native text undo.

### A custom SwiftUI-window field editor

Rejected as a fragile dependency on private `NSTextField`/cell behavior.

### One global Basic/Advanced chronology

Rejected because the modes retain independent hidden content and Undo should
operate on the active editing buffer without switching modes.

### Timer-defined or field-session undo groups

Rejected because pauses are not user actions and session collapse changes the
meaning of prior edits after focus leaves a field.

## Follow-up

- Replace the superseded 2026-07-10 implementation plan before making further
  source changes.
- Keep the routing spike as historical evidence; do not treat its provisional
  700 ms granularity as an accepted product rule.
- Verify all implementation work against the improved behavior spec and
  [Undo / Redo — Manual Runtime Test Plan](../MANUAL-TEST-UNDO-REDO.md).
