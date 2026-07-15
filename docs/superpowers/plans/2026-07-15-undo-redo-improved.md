# Undo / Redo (Improved) Implementation Plan

> **For agentic workers:** This plan is executed **inline and collaboratively** — Claude implements task-by-task in the working session; the user live-tests at each checkpoint against the manual test plan. Steps use checkbox (`- [ ]`) syntax for tracking. The pure-logic tasks (2–4) are strict TDD in ObfuskoderKit; the AppKit-wiring tasks (5–8) are verified by the runtime gate, not unit tests.

**Goal:** Replace the provisional timer-based two-level undo with the context-routed, model-owned, semantically-grouped undo/redo defined by the 2026-07-14 spec and ADR-0001.

**Architecture:** One pure, unit-tested grouping engine in ObfuskoderKit forms semantic edit groups (§6) from classified edit events; both modes share it, guaranteeing identical Basic/Advanced behavior. Each mode owns a `Foundation.UndoManager` as its committed-action stack. A `FormActionRecorder` registers each closed group / form operation as a mode-slice snapshot carrying caret/selection + focus intent. An app-side `UndoRouter` chooses the target (main form vs. auxiliary native field vs. disabled) from the key window and first responder.

**Tech Stack:** Swift 6.2, Swift Testing, SwiftUI (app lifecycle) + AppKit (`NSTextField`/`NSTextView` via `NSViewRepresentable`), `Foundation.UndoManager`.

## Global Constraints

_Every task's requirements implicitly include this section. Values copied verbatim from the spec/ADR._

- **No idle timer, no focus-loss collapse.** Group boundaries are semantic only: insertion/deletion transitions, forward/backward-delete transitions, caret/selection moves, focus changes, discrete commands, form operations, mode changes. A typing pause of any length is **not** a boundary. Leaving a field preserves the groups already formed in it. (spec §6, ADR §4)
- **A group whose final content equals its initial content records nothing.** (spec §6, §9)
- **Two independent per-mode histories.** Basic = {email, linkText, linkTitle, subject, Clear, Apply}. Advanced = {HTML, Clear, Apply}. Mode switch is not undoable, clears neither history nor redo future, and closes the source mode's open group first. Undo never switches modes or touches the inactive mode. (spec §3, §4)
- **Mode isolation at the content slice.** An action restores only its mode's content slice, never a whole `FormState` that could overwrite the inactive mode or reverse a mode switch. (ADR §5, spec §4/§7.4)
- **Context routing.** Undo/Redo target the frontmost valid editing context. Main-form fields' native text undo is disabled; the model owns their undo. Auxiliary editable fields (Save/Manage sheets, Settings) keep native text undo, which takes priority. No available action ⇒ disabled; never reach behind a modal to mutate the form. (spec §3, ADR §2/§3)
- **Menu presentation.** Undo/Redo are the first Edit-menu commands, `⌘Z` / `⇧⌘Z`. Disabled titles read "Undo"/"Redo"; enabled titles name the next result via the system-localized prefix + a localized action name (`undoMenuTitle(forUndoActionName:)`). No content-area undo buttons. Titles/enabled state refresh after mode or key-window change. (spec §2, §10)
- **Every successful main-form Undo/Redo makes its result evident:** focus the affected field, restore its recorded caret/selection (never select-all unless that was recorded), scroll Advanced to reveal the range. Focus must never move to the result/preview. No toast for routine undo. (spec §7, §8)
- **Action names:** Typing, Delete, Cut, Paste, Replace, Complete Link Text, Clear Form, Apply "<name>". Symmetric Redo titles. (spec §10)
- **§12 saved-values management undo (Rename/Delete/Reorder) is OUT OF SCOPE** for this plan (deferred to a follow-up). Auxiliary fields keep native text undo (§12.1); no sheet-scoped management history is built here.
- **Verification gate:** `docs/MANUAL-TEST-UNDO-REDO.md` must pass in a normally-launched build. Unit tests alone do not complete the feature. (spec §14, ADR §6)
- Commits end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Do not touch `MAC-ASSED-MAC-APPS.md`.

---

## File Structure

**ObfuskoderKit (pure, unit-tested):**
- Create `Sources/ObfuskoderKit/UndoTypes.swift` — value types: `TextSelection`, `FieldID`, `EditKind`, `EditCommand`, `RawTextEdit`, `TextEditEvent`, `CommittedEdit`, `RestoreTarget`; `FieldID`↔`FormState` bridging (`FormState[field]` subscript, `FieldID.mode`).
- Create `Sources/ObfuskoderKit/EditClassifier.swift` — `classifyEdit(...)` pure function.
- Create `Sources/ObfuskoderKit/UndoGroupingEngine.swift` — the semantic grouping state machine.
- Rename `Sources/ObfuskoderKit/FormUndoRecorder.swift` → `Sources/ObfuskoderKit/FormActionRecorder.swift` — snapshot recorder carrying focus/selection.
- Create tests: `EditClassifierTests.swift`, `UndoGroupingEngineTests.swift`, `FormActionRecorderTests.swift`. Delete `FormUndoRecorderTests.swift`.

**App (AppKit wiring, runtime-gated):**
- Modify `Obfuskoder/AppModel.swift` — replace burst system with per-mode engines + recorders; edit/selection/focus intake; Clear/Apply; undo/redo; menu-state mirror; `pendingRestore`.
- Modify `Obfuskoder/Views/MacTextField.swift` — emit `RawTextEdit` + selection/focus events; disable field-editor native undo; apply `pendingRestore`.
- Modify `Obfuskoder/Views/MacTextEditor.swift` — same, plus scroll-to-selection.
- Modify `Obfuskoder/Views/BasicFormView.swift`, `Obfuskoder/Views/AdvancedFormView.swift` — wire new callbacks with `FieldID`.
- Create `Obfuskoder/UndoRouter.swift` — key-window/first-responder routing + `WindowAccessor`.
- Modify `Obfuskoder/AppCommands.swift` — Undo/Redo target the router; mode toggles close the source group.
- Modify `Obfuskoder/Views/ContentView.swift` — install `WindowAccessor`, mode-switch closes group, refresh hooks.
- Modify `Obfuskoder/Strings.swift` — action-name strings; remove the pre-composed `undoTyping`/`redoTyping`.

---

## Task 1: Spike — Basic field-editor edit-signal capture

**Goal:** Prove what edit signal we can reliably capture from a main-form `NSTextField`'s field editor, before committing to the classifier. This resolves the plan's one real risk.

**Files:**
- Temporary logging only inside `Obfuskoder/Views/MacTextField.swift` (revert after).

**Steps:**

- [ ] **Step 1: Add temporary logging** to `MacTextField.Coordinator` capturing, on every change: old string, new string, `field.currentEditor()?.selectedRange` before and after, and any `doCommandBy:` selector seen since the last change. Log on Cut (`⌘X`), Paste (`⌘V`), Backspace, Forward-Delete (fn-Delete), typing a single char, typing fast, and typing over a selection.

- [ ] **Step 2: Run the app**, exercise each case in the Email field, and record which of these we can detect: (a) backward vs. forward deletion, (b) paste vs. multi-char typing, (c) cut vs. plain selection-deletion, (d) selection-replacement.

- [ ] **Step 3: Decision gate.** Confirm the classifier design:
  - If delete-direction arrives via `doCommandBy:` (`deleteBackward:`/`deleteForward:`) → pass it as an `EditCommand` hint.
  - If Cut/Paste are **not** distinguishable on `NSTextField` → accept the diff heuristic (multi-char single-event insert ⇒ Paste; non-empty prior selection replaced ⇒ Replace; a cut degrades to Delete) and note the limitation in the manual plan's Cut row.
  - Record findings in `docs/undo-routing-findings.md` (append a dated "Task 1b" section). **Do not proceed to Task 2 until the classifier's inputs are confirmed.**

- [ ] **Step 4: Revert the temporary logging.** `git checkout Obfuskoder/Views/MacTextField.swift` (leave it as it is on the branch — Task 6 rewrites it properly).

- [ ] **Step 5: Commit** the findings doc only.

```bash
git add docs/undo-routing-findings.md
git commit -m "Undo spike 1b: confirm Basic field-editor edit-signal capture"
```

---

## Task 2: Pure value types + edit classification

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/UndoTypes.swift`
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/EditClassifier.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/EditClassifierTests.swift`

**Interfaces:**
- Produces: `TextSelection(location:length:)`, `FieldID` (`.email/.linkText/.linkTitle/.subject/.advancedHTML`), `EditKind` (`.insert/.deleteBackward/.deleteForward/.cut/.paste/.replace/.completeLinkText`) with `.isDiscrete`, `EditCommand` (`.deleteBackward/.deleteForward/.cut/.paste/.completeLinkText`), `RawTextEdit`, `FormState[field]` subscript, `FieldID.mode`, and `classifyEdit(before:beforeSelection:after:afterSelection:command:) -> EditKind`.

- [ ] **Step 1: Write `UndoTypes.swift`.**

```swift
import Foundation

/// A caret (length 0) or ranged selection, in UTF-16 offsets to match AppKit's
/// `NSRange`.
public struct TextSelection: Equatable, Sendable {
    public var location: Int
    public var length: Int
    public init(location: Int, length: Int = 0) {
        self.location = location
        self.length = length
    }
}

/// Identifies an editable field across both modes' form histories.
public enum FieldID: Hashable, Sendable {
    case email, linkText, linkTitle, subject   // Basic
    case advancedHTML                          // Advanced

    /// Which mode's history this field belongs to.
    public var mode: FormMode { self == .advancedHTML ? .advanced : .basic }
}

/// The semantic class of a single edit (spec §6/§10).
public enum EditKind: Equatable, Sendable {
    case insert, deleteBackward, deleteForward
    case cut, paste, replace, completeLinkText

    /// Discrete kinds are always their own single-action group and never coalesce.
    public var isDiscrete: Bool {
        switch self {
        case .insert, .deleteBackward, .deleteForward: return false
        case .cut, .paste, .replace, .completeLinkText: return true
        }
    }
}

/// A hint from the AppKit capture layer when the originating command is known.
public enum EditCommand: Sendable {
    case deleteBackward, deleteForward, cut, paste, completeLinkText
}

/// Raw before/after captured by a view before classification.
public struct RawTextEdit: Sendable {
    public var before: String
    public var beforeSelection: TextSelection
    public var after: String
    public var afterSelection: TextSelection
    public var command: EditCommand?
    public init(before: String, beforeSelection: TextSelection,
                after: String, afterSelection: TextSelection,
                command: EditCommand? = nil) {
        self.before = before; self.beforeSelection = beforeSelection
        self.after = after; self.afterSelection = afterSelection
        self.command = command
    }
}

extension FormState {
    /// Read/write one field's text by identity, so undo records stay generic.
    public subscript(field: FieldID) -> String {
        get {
            switch field {
            case .email: return basic.email
            case .linkText: return basic.linkText
            case .linkTitle: return basic.linkTitle
            case .subject: return basic.subject
            case .advancedHTML: return advanced
            }
        }
        set {
            switch field {
            case .email: basic.email = newValue
            case .linkText: basic.linkText = newValue
            case .linkTitle: basic.linkTitle = newValue
            case .subject: basic.subject = newValue
            case .advancedHTML: advanced = newValue
            }
        }
    }
}
```

- [ ] **Step 2: Write the failing classifier tests.**

```swift
import Testing
import ObfuskoderKit

@Test func explicitCommandsWin() {
    let sel = TextSelection(location: 1)
    #expect(classifyEdit(before: "ab", beforeSelection: sel, after: "a",
                         afterSelection: TextSelection(location: 1), command: .deleteBackward) == .deleteBackward)
    #expect(classifyEdit(before: "ab", beforeSelection: TextSelection(location: 0),
                         after: "b", afterSelection: TextSelection(location: 0), command: .deleteForward) == .deleteForward)
    #expect(classifyEdit(before: "abc", beforeSelection: TextSelection(location: 0, length: 3),
                         after: "", afterSelection: TextSelection(location: 0), command: .cut) == .cut)
}

@Test func inferInsertVsPaste() {
    // single new char at caret ⇒ typing
    #expect(classifyEdit(before: "a", beforeSelection: TextSelection(location: 1),
                         after: "ab", afterSelection: TextSelection(location: 2), command: nil) == .insert)
    // multi-char in one event ⇒ paste
    #expect(classifyEdit(before: "a", beforeSelection: TextSelection(location: 1),
                         after: "aXYZ", afterSelection: TextSelection(location: 4), command: nil) == .paste)
}

@Test func inferReplaceWhenSelectionExisted() {
    #expect(classifyEdit(before: "abcd", beforeSelection: TextSelection(location: 1, length: 2),
                         after: "aXd", afterSelection: TextSelection(location: 2), command: nil) == .replace)
}

@Test func inferDeleteDirectionFromCaret() {
    #expect(classifyEdit(before: "ab", beforeSelection: TextSelection(location: 2),
                         after: "a", afterSelection: TextSelection(location: 1), command: nil) == .deleteBackward)
    #expect(classifyEdit(before: "ab", beforeSelection: TextSelection(location: 0),
                         after: "b", afterSelection: TextSelection(location: 0), command: nil) == .deleteForward)
}
```

- [ ] **Step 3: Run — verify red.** `swift test --filter EditClassifier` → fails ("cannot find 'classifyEdit'").

- [ ] **Step 4: Write `EditClassifier.swift`.**

```swift
import Foundation

/// Classify a raw edit into a semantic `EditKind`. An explicit command hint from
/// the capture layer always wins; otherwise infer from the before/after diff.
public func classifyEdit(before: String, beforeSelection: TextSelection,
                         after: String, afterSelection: TextSelection,
                         command: EditCommand?) -> EditKind {
    switch command {
    case .deleteBackward: return .deleteBackward
    case .deleteForward:  return .deleteForward
    case .cut:            return .cut
    case .paste:          return .paste
    case .completeLinkText: return .completeLinkText
    case nil: break
    }
    if beforeSelection.length > 0, before != after { return .replace }
    let beforeCount = before.count, afterCount = after.count
    if afterCount > beforeCount { return afterCount - beforeCount > 1 ? .paste : .insert }
    if afterCount < beforeCount {
        return afterSelection.location < beforeSelection.location ? .deleteBackward : .deleteForward
    }
    return .replace   // same length, changed content ⇒ selection replacement
}
```

- [ ] **Step 5: Run — verify green.** `swift test --filter EditClassifier` → PASS. Confirm the whole suite still builds: `swift test`.

- [ ] **Step 6: Commit.**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/UndoTypes.swift ObfuskoderKit/Sources/ObfuskoderKit/EditClassifier.swift ObfuskoderKit/Tests/ObfuskoderKitTests/EditClassifierTests.swift
git commit -m "Undo: edit classification + undo value types (Kit, tested)"
```

---

## Task 3: Pure semantic grouping engine

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/UndoGroupingEngine.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/UndoGroupingEngineTests.swift`

**Interfaces:**
- Consumes: `TextSelection`, `FieldID`, `EditKind` (Task 2).
- Produces: `TextEditEvent`, `CommittedEdit`, and `UndoGroupingEngine` with `mutating func ingest(_:) -> [CommittedEdit]`, `mutating func endGroup() -> CommittedEdit?`, `var openGroupKind: EditKind?`, `var openGroupHasNetChange: Bool`.

- [ ] **Step 1: Add types to `UndoTypes.swift`** (append):

```swift
/// A classified edit ready for grouping.
public struct TextEditEvent: Sendable {
    public var field: FieldID
    public var kind: EditKind
    public var before: String
    public var beforeSelection: TextSelection
    public var after: String
    public var afterSelection: TextSelection
    public init(field: FieldID, kind: EditKind, before: String,
                beforeSelection: TextSelection, after: String, afterSelection: TextSelection) {
        self.field = field; self.kind = kind
        self.before = before; self.beforeSelection = beforeSelection
        self.after = after; self.afterSelection = afterSelection
    }
}

/// A closed, net-changing group ready to register as one undo action.
public struct CommittedEdit: Equatable, Sendable {
    public var field: FieldID
    public var kind: EditKind
    public var before: String
    public var beforeSelection: TextSelection
    public var after: String
    public var afterSelection: TextSelection
}
```

- [ ] **Step 2: Write the failing engine tests** (encode every §6 rule in the manual plan §2):

```swift
import Testing
import ObfuskoderKit

private func typing(_ field: FieldID, _ before: String, _ after: String,
                    at loc: Int) -> TextEditEvent {
    TextEditEvent(field: field, kind: .insert, before: before,
                  beforeSelection: TextSelection(location: loc),
                  after: after, afterSelection: TextSelection(location: loc + (after.count - before.count)))
}

@Test func continuousTypingIsOneGroup() {   // 2.1 / 2.2 (pause never breaks)
    var e = UndoGroupingEngine()
    #expect(e.ingest(typing(.email, "", "a", at: 0)).isEmpty)
    #expect(e.ingest(typing(.email, "a", "ab", at: 1)).isEmpty)
    #expect(e.ingest(typing(.email, "ab", "abc", at: 2)).isEmpty)
    let c = e.endGroup()
    #expect(c?.before == "" && c?.after == "abc" && c?.kind == .insert)
}

@Test func caretMoveEndsGroup() {            // 2.3
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "", "abcdef", at: 0))     // one run
    let first = e.endGroup()                                // caret move ⇒ close
    #expect(first?.after == "abcdef")
    // type XYZ at a new location; its beforeSelection ≠ prior afterSelection
    let x = TextEditEvent(field: .email, kind: .insert, before: "abcdef",
                          beforeSelection: TextSelection(location: 3),
                          after: "abcXYZdef", afterSelection: TextSelection(location: 6))
    #expect(e.ingest(x).isEmpty)
    #expect(e.endGroup()?.after == "abcXYZdef")
}

@Test func insertThenDeleteAreTwoGroups() {  // 2.4
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "", "abc", at: 0))
    let del = TextEditEvent(field: .email, kind: .deleteBackward, before: "abc",
                            beforeSelection: TextSelection(location: 3),
                            after: "ab", afterSelection: TextSelection(location: 2))
    let committed = e.ingest(del)             // kind change closes the typing group
    #expect(committed.count == 1 && committed[0].after == "abc" && committed[0].kind == .insert)
    #expect(e.endGroup()?.kind == .deleteBackward)
}

@Test func backwardAndForwardDeleteAreDistinct() {  // 2.5
    var e = UndoGroupingEngine()
    let back = TextEditEvent(field: .email, kind: .deleteBackward, before: "abcd",
                             beforeSelection: TextSelection(location: 4),
                             after: "abc", afterSelection: TextSelection(location: 3))
    _ = e.ingest(back)
    let fwd = TextEditEvent(field: .email, kind: .deleteForward, before: "abc",
                            beforeSelection: TextSelection(location: 0),
                            after: "bc", afterSelection: TextSelection(location: 0))
    let committed = e.ingest(fwd)
    #expect(committed.count == 1 && committed[0].kind == .deleteBackward)
}

@Test func discreteActionIsItsOwnGroupAndClosesPrior() {  // 2.6/2.7/2.8
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "", "ab", at: 0))
    let paste = TextEditEvent(field: .email, kind: .paste, before: "ab",
                              beforeSelection: TextSelection(location: 2),
                              after: "abXYZ", afterSelection: TextSelection(location: 5))
    let committed = e.ingest(paste)
    #expect(committed.count == 2)                 // prior typing + the paste
    #expect(committed[0].kind == .insert && committed[1].kind == .paste)
    #expect(!e.hasOpenGroupPublic)                // discrete leaves nothing open
}

@Test func fieldChangeEndsGroupButKeepsBoth() {   // 2.9
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "", "x", at: 0))
    let subj = typing(.subject, "", "y", at: 0)   // different field
    let committed = e.ingest(subj)
    #expect(committed.count == 1 && committed[0].field == .email)
    #expect(e.endGroup()?.field == .subject)
}

@Test func returnToStartRecordsNothing() {        // 2.10 / §9
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "abc", "abcd", at: 3))
    // A later ingest returns after to the group's original before:
    let undoToStart = TextEditEvent(field: .email, kind: .insert, before: "abcd",
                                    beforeSelection: TextSelection(location: 4),
                                    after: "abc", afterSelection: TextSelection(location: 3))
    // Not a real extension (shrinks); treat as a fresh group whose net we then check.
    _ = e.ingest(undoToStart)
    // Force close: the *last* open group ("abcd"->"abc") nets a change, but the
    // canonical no-op is a single group whose before == after:
    var e2 = UndoGroupingEngine()
    let noop = TextEditEvent(field: .email, kind: .replace, before: "abc",
                             beforeSelection: TextSelection(location: 0, length: 3),
                             after: "abc", afterSelection: TextSelection(location: 3))
    #expect(e2.ingest(noop).isEmpty)              // discrete replace, before==after ⇒ nothing
}

@Test func openGroupStateForMenu() {
    var e = UndoGroupingEngine()
    #expect(e.openGroupKind == nil && !e.openGroupHasNetChange)
    _ = e.ingest(typing(.email, "", "a", at: 0))
    #expect(e.openGroupKind == .insert && e.openGroupHasNetChange)
}
```

_(Add a tiny `hasOpenGroupPublic` accessor in the engine for the test, or assert via `openGroupKind == nil`.)_

- [ ] **Step 3: Run — verify red.** `swift test --filter UndoGroupingEngine` → fails.

- [ ] **Step 4: Write `UndoGroupingEngine.swift`.**

```swift
import Foundation

/// Forms semantic undo groups from a stream of classified edits (spec §6).
/// Pure and value-typed: no timers, no AppKit. One instance per mode.
public struct UndoGroupingEngine: Sendable {
    private struct OpenGroup {
        var field: FieldID
        var kind: EditKind
        var before: String
        var beforeSelection: TextSelection
        var after: String
        var afterSelection: TextSelection
    }
    private var open: OpenGroup?

    public init() {}

    public var openGroupKind: EditKind? { open?.kind }
    public var openGroupHasNetChange: Bool { open.map { $0.before != $0.after } ?? false }
    public var hasOpenGroupPublic: Bool { open != nil }

    /// Ingest one classified edit. Returns the edits committed as a result:
    /// closing a prior coalescing group can commit one, and a discrete edit
    /// commits itself immediately (so up to two).
    public mutating func ingest(_ e: TextEditEvent) -> [CommittedEdit] {
        var committed: [CommittedEdit] = []
        if e.kind.isDiscrete {
            if let c = close() { committed.append(c) }
            open = nil
            if e.before != e.after {
                committed.append(CommittedEdit(field: e.field, kind: e.kind,
                    before: e.before, beforeSelection: e.beforeSelection,
                    after: e.after, afterSelection: e.afterSelection))
            }
            return committed
        }
        if let g = open, canExtend(g, with: e) {
            open!.after = e.after
            open!.afterSelection = e.afterSelection
        } else {
            if let c = close() { committed.append(c) }
            open = OpenGroup(field: e.field, kind: e.kind, before: e.before,
                             beforeSelection: e.beforeSelection,
                             after: e.after, afterSelection: e.afterSelection)
        }
        return committed
    }

    /// Close the open group at a boundary (selection move, focus/mode change,
    /// form op, undo/redo). Returns the committed edit if it netted a change.
    public mutating func endGroup() -> CommittedEdit? {
        let c = close()
        open = nil
        return c
    }

    private func canExtend(_ g: OpenGroup, with e: TextEditEvent) -> Bool {
        g.field == e.field && g.kind == e.kind
            && g.after == e.before && g.afterSelection == e.beforeSelection
    }

    private func close() -> CommittedEdit? {
        guard let g = open, g.before != g.after else { return nil }
        return CommittedEdit(field: g.field, kind: g.kind, before: g.before,
            beforeSelection: g.beforeSelection, after: g.after, afterSelection: g.afterSelection)
    }
}
```

- [ ] **Step 5: Run — verify green.** `swift test --filter UndoGroupingEngine` → PASS. Fix the `returnToStart` test to match the final API if needed (the canonical no-op assertion is the discrete `before==after` case). Full suite: `swift test`.

- [ ] **Step 6: Commit.**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/UndoGroupingEngine.swift ObfuskoderKit/Sources/ObfuskoderKit/UndoTypes.swift ObfuskoderKit/Tests/ObfuskoderKitTests/UndoGroupingEngineTests.swift
git commit -m "Undo: semantic grouping engine (Kit, tested)"
```

---

## Task 4: Snapshot recorder with focus/selection

**Files:**
- Rename: `FormUndoRecorder.swift` → `FormActionRecorder.swift`
- Delete: `FormUndoRecorderTests.swift`; Create: `FormActionRecorderTests.swift`

**Interfaces:**
- Consumes: `FormState`, `FormMode`, `RestoreTarget`.
- Produces: `RestoreTarget(field:selection:)` and `FormActionRecorder` with `record(mode:before:after:name:undoFocus:redoFocus:)`.

- [ ] **Step 1: Add `RestoreTarget` to `UndoTypes.swift`** (append):

```swift
/// Where a restore should place first responder + caret/selection.
public struct RestoreTarget: Equatable, Sendable {
    public var field: FieldID
    public var selection: TextSelection
    public init(field: FieldID, selection: TextSelection) {
        self.field = field; self.selection = selection
    }
}
```

- [ ] **Step 2: Write the failing recorder tests** (mirror the old ones + focus):

```swift
import Testing
import Foundation
import ObfuskoderKit

@MainActor
private final class Sink {
    var form: FormState
    var lastFocus: RestoreTarget?
    init(_ f: FormState) { form = f }
    func apply(_ f: FormState, _ focus: RestoreTarget?) { form = f; lastFocus = focus }
}

@MainActor @Test func undoRestoresSliceFocusAndName() {
    var form = FormState(mode: .basic, basic: BasicFields(email: "a@b.com"), advanced: "<keep>")
    let sink = Sink(form)
    let um = UndoManager(); um.groupsByEvent = false
    let rec = FormActionRecorder(undoManager: um, get: { sink.form }, apply: sink.apply)

    let before = sink.form
    sink.form.basic.email = "changed@b.com"; form = sink.form
    um.beginUndoGrouping()
    rec.record(mode: .basic, before: before, after: sink.form, name: "Typing",
               undoFocus: RestoreTarget(field: .email, selection: TextSelection(location: 1)),
               redoFocus: RestoreTarget(field: .email, selection: TextSelection(location: 13)))
    um.endUndoGrouping()
    #expect(um.undoActionName == "Typing")

    um.undo()
    #expect(sink.form.basic.email == "a@b.com")
    #expect(sink.form.advanced == "<keep>")                       // other mode untouched
    #expect(sink.lastFocus == RestoreTarget(field: .email, selection: TextSelection(location: 1)))

    um.redo()
    #expect(sink.form.basic.email == "changed@b.com")
    #expect(sink.lastFocus?.selection == TextSelection(location: 13))
}

@MainActor @Test func undoOfApplyKeepsModeRestoresDestinationSlice() {
    var form = FormState(mode: .advanced, advanced: "X")
    let sink = Sink(form)
    let um = UndoManager(); um.groupsByEvent = false
    let rec = FormActionRecorder(undoManager: um, get: { sink.form }, apply: sink.apply)

    let before = sink.form
    sink.form.apply(Preset(name: "P", payload: .basic(BasicFields(email: "p@x.com")))); form = sink.form
    um.beginUndoGrouping()
    rec.record(mode: .basic, before: before, after: sink.form, name: "Apply “P”",
               undoFocus: RestoreTarget(field: .email, selection: TextSelection(location: 0)),
               redoFocus: RestoreTarget(field: .email, selection: TextSelection(location: 0)))
    um.endUndoGrouping()

    um.undo()
    #expect(sink.form.mode == .basic)              // mode switch NOT reverted
    #expect(sink.form.basic == BasicFields())      // basic slice restored to prior empty
    #expect(sink.form.advanced == "X")             // advanced untouched
}
```

- [ ] **Step 3: Run — verify red.** `swift test --filter FormActionRecorder` → fails.

- [ ] **Step 4: Write `FormActionRecorder.swift`** (replaces the old file's contents):

```swift
import Foundation

/// Registers undoable form actions as mode-slice snapshots that also carry the
/// focus/caret to restore (spec §7/§8). Undo restores `before` + `undoFocus`;
/// the automatically-registered redo restores `after` + `redoFocus`. Restoring
/// only the action's mode slice preserves the inactive mode and never reverses a
/// mode switch (ADR §5). `UndoManager` is Foundation, so this stays unit-testable.
@MainActor
public final class FormActionRecorder {
    private let undoManager: UndoManager
    private let getForm: () -> FormState
    private let apply: (FormState, RestoreTarget?) -> Void

    public init(undoManager: UndoManager,
                get: @escaping () -> FormState,
                apply: @escaping (FormState, RestoreTarget?) -> Void) {
        self.undoManager = undoManager
        self.getForm = get
        self.apply = apply
    }

    public func record(mode: FormMode, before: FormState, after: FormState,
                       name: String, undoFocus: RestoreTarget?, redoFocus: RestoreTarget?) {
        undoManager.registerUndo(withTarget: self) { rec in
            MainActor.assumeIsolated {
                rec.restore(before, mode: mode, focus: undoFocus)
                rec.record(mode: mode, before: after, after: before,
                           name: name, undoFocus: redoFocus, redoFocus: undoFocus)
            }
        }
        undoManager.setActionName(name)
    }

    private func restore(_ snapshot: FormState, mode: FormMode, focus: RestoreTarget?) {
        var next = getForm()
        switch mode {
        case .basic:    next.basic = snapshot.basic
        case .advanced: next.advanced = snapshot.advanced
        }
        apply(next, focus)
    }
}
```

- [ ] **Step 5: Run — verify green.** `swift test --filter FormActionRecorder` → PASS. `swift test` (whole suite green; the old `FormUndoRecorderTests` is deleted).

- [ ] **Step 6: Commit.**

```bash
git rm ObfuskoderKit/Tests/ObfuskoderKitTests/FormUndoRecorderTests.swift
git add ObfuskoderKit/Sources/ObfuskoderKit/FormActionRecorder.swift ObfuskoderKit/Sources/ObfuskoderKit/FormUndoRecorder.swift ObfuskoderKit/Sources/ObfuskoderKit/UndoTypes.swift ObfuskoderKit/Tests/ObfuskoderKitTests/FormActionRecorderTests.swift
git commit -m "Undo: form action recorder carries focus/selection (Kit, tested)"
```

_(If `git mv` is preferred: `git mv FormUndoRecorder.swift FormActionRecorder.swift` first, then overwrite contents.)_

---

## Task 5: AppModel — replace burst system with engine + recorders

**Files:**
- Modify: `Obfuskoder/AppModel.swift`
- Modify: `Obfuskoder/Strings.swift`

**Interfaces:**
- Consumes: `UndoGroupingEngine`, `classifyEdit`, `FormActionRecorder`, `RawTextEdit`, `TextEditEvent`, `CommittedEdit`, `RestoreTarget`, `FieldID`.
- Produces (for views/router/commands): `handleFieldEdit(_:_:)`, `noteSelection(_:_:)`, `noteFocus(_:)`, `noteBlur(_:)`, `switchMode(to:)`, `clearActiveForm()`, `apply(_:name:)`, `undo()`, `redo()`, and observable `canUndo/canRedo/undoTitle/redoTitle`, `pendingRestore`, `consumePendingRestore()`.

- [ ] **Step 1: Add action-name strings** to `Strings.swift`; remove the now-unused pre-composed combos. Keep `clearForm`/`applySavedValues` (used elsewhere) but the undo NAMES are:

```swift
// Undo/redo action names (spec §10). The "Undo "/"Redo " prefix is added by
// UndoManager.undoMenuTitle(forUndoActionName:), so store only the bare names.
static let undoTyping = String(localized: "Typing")
static let undoDelete = String(localized: "Delete")
static let undoCut = String(localized: "Cut")
static let undoPaste = String(localized: "Paste")
static let undoReplace = String(localized: "Replace")
static let undoCompleteLinkText = String(localized: "Complete Link Text")
static let undoClearForm = String(localized: "Clear Form")
static func undoApply(_ name: String) -> String { String(localized: "Apply “\(name)”") }
```
Delete the old `typing`, `undoTyping = "Undo Typing"`, `redoTyping = "Redo Typing"` (replace their references). Keep `clearForm` for the menu-item label; the undo action name uses `undoClearForm` (same text).

- [ ] **Step 2: Rewrite `AppModel`'s undo section.** Remove `history`, `index`, `editBurstIdle`, `inSession`, `sessionCanUndo`, `sessionCanRedo`, `noteEdit`, `beginEditBurst`, `endEditBurst`, `checkpoint`, `appendCheckpoint`, `restoreSlice`. Keep `basicUndo`, `advancedUndo`, `activeUndoManager`, the notification observers, `canUndo/canRedo/undoTitle/redoTitle`. Add:

```swift
// Per-mode semantic grouping engines (value types; mutate the active one).
@ObservationIgnored private var basicEngine = UndoGroupingEngine()
@ObservationIgnored private var advancedEngine = UndoGroupingEngine()

// Focus/caret to restore after undo/redo, consumed by the field views.
private(set) var pendingRestore: RestoreTarget?
func consumePendingRestore() { pendingRestore = nil }

// Most recently focused field + its selection, for Clear/Apply undo focus.
@ObservationIgnored private var lastFocusedField: FieldID?
@ObservationIgnored private var lastSelection: [FieldID: TextSelection] = [:]

@ObservationIgnored private lazy var basicRecorder = FormActionRecorder(
    undoManager: basicUndo, get: { [weak self] in self?.form ?? FormState() },
    apply: { [weak self] form, focus in self?.applyRestored(form, focus) })
@ObservationIgnored private lazy var advancedRecorder = FormActionRecorder(
    undoManager: advancedUndo, get: { [weak self] in self?.form ?? FormState() },
    apply: { [weak self] form, focus in self?.applyRestored(form, focus) })
private func recorder(for mode: FormMode) -> FormActionRecorder {
    mode == .basic ? basicRecorder : advancedRecorder
}
private func applyRestored(_ form: FormState, _ focus: RestoreTarget?) {
    self.form = form
    self.pendingRestore = focus
    scheduleEncode()
}
```

- [ ] **Step 3: Add the edit/selection/focus intake.**

```swift
/// A view reports a raw edit; classify, group, and register any closed groups.
func handleFieldEdit(_ field: FieldID, _ raw: RawTextEdit) {
    let kind = classifyEdit(before: raw.before, beforeSelection: raw.beforeSelection,
                            after: raw.after, afterSelection: raw.afterSelection, command: raw.command)
    let event = TextEditEvent(field: field, kind: kind, before: raw.before,
                              beforeSelection: raw.beforeSelection,
                              after: raw.after, afterSelection: raw.afterSelection)
    lastFocusedField = field
    lastSelection[field] = raw.afterSelection
    let committed = mutateEngine(field.mode) { $0.ingest(event) }
    for c in committed { register(c) }
    refreshUndoState()
}

func noteSelection(_ field: FieldID, _ selection: TextSelection) {
    lastFocusedField = field
    lastSelection[field] = selection
    if let c = mutateEngine(field.mode, { $0.endGroup() }) { register(c) }
    refreshUndoState()
}

func noteFocus(_ field: FieldID) { lastFocusedField = field }

func noteBlur(_ field: FieldID) {
    if let c = mutateEngine(field.mode, { $0.endGroup() }) { register(c) }
    refreshUndoState()
}

private func register(_ c: CommittedEdit) {
    var before = form; before[c.field] = c.before
    var after = form;  after[c.field] = c.after
    recorder(for: c.field.mode).record(
        mode: c.field.mode, before: before, after: after, name: actionName(c.kind),
        undoFocus: RestoreTarget(field: c.field, selection: c.beforeSelection),
        redoFocus: RestoreTarget(field: c.field, selection: c.afterSelection))
}

private func actionName(_ kind: EditKind) -> String {
    switch kind {
    case .insert: return UIStrings.undoTyping
    case .deleteBackward, .deleteForward: return UIStrings.undoDelete
    case .cut: return UIStrings.undoCut
    case .paste: return UIStrings.undoPaste
    case .replace: return UIStrings.undoReplace
    case .completeLinkText: return UIStrings.undoCompleteLinkText
    }
}

// Mutate the active mode's engine in place (structs can't be a computed lvalue).
private func mutateEngine<R>(_ mode: FormMode, _ body: (inout UndoGroupingEngine) -> R) -> R {
    mode == .basic ? body(&basicEngine) : body(&advancedEngine)
}
private func activeEngineSnapshot() -> UndoGroupingEngine { form.mode == .basic ? basicEngine : advancedEngine }
```

- [ ] **Step 4: Rewrite Clear/Apply, undo/redo, and menu mirror.**

```swift
func switchMode(to mode: FormMode) {
    guard form.mode != mode else { return }
    if let c = mutateEngine(form.mode, { $0.endGroup() }) { register(c) }  // §4: close source group
    form.mode = mode
    scheduleEncode()
    refreshUndoState()
}

func clearActiveForm() {
    if let c = mutateEngine(form.mode, { $0.endGroup() }) { register(c) }  // §7.3: close open group
    guard !form.activeIsEmpty else { return }                             // §7.3 no-op
    let before = form
    let focusField = lastFocusedField ?? (form.mode == .basic ? .email : .advancedHTML)
    let focusSel = lastSelection[focusField] ?? TextSelection(location: 0)
    form.clearActive()
    scheduleEncode()
    recorder(for: form.mode).record(
        mode: form.mode, before: before, after: form, name: UIStrings.undoClearForm,
        undoFocus: RestoreTarget(field: focusField, selection: focusSel),
        redoFocus: RestoreTarget(field: form.mode == .basic ? .email : .advancedHTML,
                                 selection: TextSelection(location: 0)))
    refreshUndoState()
}

func apply(_ preset: Preset, name: String) {
    if let c = mutateEngine(form.mode, { $0.endGroup() }) { register(c) }  // §7.4: close SOURCE group
    let destinationMode: FormMode = { if case .basic = preset.payload { return .basic } else { return .advanced } }()
    let before = form
    form.apply(preset)                                                     // may switch mode; not undone
    scheduleEncode()
    guard form[destinationFirstField(destinationMode)] != before[destinationFirstField(destinationMode)]
            || destinationSliceChanged(before, form, destinationMode) else { refreshUndoState(); return }  // §7.4 identical ⇒ no history
    let priorFocus = lastFocusedField.flatMap { $0.mode == destinationMode ? $0 : nil } ?? destinationFirstField(destinationMode)
    recorder(for: destinationMode).record(
        mode: destinationMode, before: before, after: form, name: UIStrings.undoApply(name),
        undoFocus: RestoreTarget(field: priorFocus, selection: lastSelection[priorFocus] ?? TextSelection(location: 0)),
        redoFocus: RestoreTarget(field: destinationFirstField(destinationMode), selection: TextSelection(location: 0)))
    refreshUndoState()
}

private func destinationFirstField(_ mode: FormMode) -> FieldID { mode == .basic ? .email : .advancedHTML }
private func destinationSliceChanged(_ a: FormState, _ b: FormState, _ mode: FormMode) -> Bool {
    mode == .basic ? a.basic != b.basic : a.advanced != b.advanced
}

func undo() {
    if let c = mutateEngine(form.mode, { $0.endGroup() }) { register(c) }  // §6: close open group first
    activeUndoManager.undo(); scheduleEncode(); refreshUndoState()
}
func redo() {
    if let c = mutateEngine(form.mode, { $0.endGroup() }) { register(c) }
    activeUndoManager.redo(); scheduleEncode(); refreshUndoState()
}

func refreshUndoState() {
    let m = activeUndoManager
    let engine = activeEngineSnapshot()
    let openName = engine.openGroupKind.map(actionName)
    canUndo = engine.openGroupHasNetChange || m.canUndo
    canRedo = !engine.openGroupHasNetChange && m.canRedo   // active typing suppresses redo (§9)
    undoTitle = engine.openGroupHasNetChange
        ? m.undoMenuTitle(forUndoActionName: openName ?? "")
        : m.undoMenuItemTitle
    redoTitle = m.redoMenuItemTitle
}
```

_Note: `apply`'s "identical content ⇒ no history" (§7.4) is the `destinationSliceChanged` guard; simplify to a single `guard destinationSliceChanged(before, form, destinationMode) else { refreshUndoState(); return }` — the first-field comparison above is redundant, drop it during implementation._

- [ ] **Step 5: Update `apply` call sites.** `apply(_:)` gained a `name:`. Find the caller (preset application — likely `PresetStore`/list UI) and pass the preset's `name`. Search: `grep -rn "\.apply(" Obfuskoder | grep -i preset`.

- [ ] **Step 6: Build.** `xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build` → compiles. (SourceKit "cannot find" errors in-editor are stale; trust xcodebuild.)

- [ ] **Step 7: Commit.**

```bash
git add Obfuskoder/AppModel.swift Obfuskoder/Strings.swift
git commit -m "Undo: AppModel drives per-mode grouping engine + focus-aware recorders"
```

_(App won't be fully live-testable until Task 6 wires the views; that's the next checkpoint.)_

---

## Task 6: View capture layer + focus restoration

**Files:**
- Modify: `Obfuskoder/Views/MacTextField.swift`, `Obfuskoder/Views/MacTextEditor.swift`, `Obfuskoder/Views/BasicFormView.swift`, `Obfuskoder/Views/AdvancedFormView.swift`

- [ ] **Step 1: `MacTextField`** — add `var field: FieldID`; replace `onChange/onEditBegin/onEditEnd` with `onEdit: (RawTextEdit) -> Void`, `onSelection: (TextSelection) -> Void`, `onFocus: () -> Void`, `onBlur: () -> Void`, and a `pendingRestore: RestoreTarget?` + `onConsumeRestore: () -> Void`. In `NoSubstitutionTextField.becomeFirstResponder`, add `editor.allowsUndo = false` (so the router excludes main-form field editors — see Task 7). In the Coordinator:
  - Track `lastText`/`lastSelection`; capture `pendingCommand: EditCommand?` set from `control(_:textView:doCommandBy:)` (`deleteBackward:`→`.deleteBackward`, `deleteForward:`→`.deleteForward`, per the Task 1 findings).
  - `controlTextDidChange`: build `RawTextEdit(before: lastText, beforeSelection: lastSelection, after: field.stringValue, afterSelection: current editor range, command: pendingCommand)`, call `onEdit`, then update `lastText`/`lastSelection`, clear `pendingCommand`, and `parent.text = field.stringValue`.
  - `controlTextDidBeginEditing`→`onFocus`; `controlTextDidEndEditing`→`onBlur`.
  - Detect caret/selection-only moves: use `NSTextViewDidChangeSelectionNotification` on the field editor (register in begin-editing) → `onSelection(range)`.
  - Tab completion path: keep the ghost-completion behavior but emit an `onEdit` with `command: .completeLinkText` (Task 8 refines the exact before/after).
  - In `updateNSView`: if `pendingRestore?.field == field`, make the field first responder, set `currentEditor()?.selectedRange = NSRange(pendingRestore.selection)`, then call `onConsumeRestore()`.

- [ ] **Step 2: `MacTextEditor`** — mirror the same event surface for `field = .advancedHTML`. Use `textView(_:shouldChangeTextIn:replacementString:)` to capture pre-change text/range (richer than `NSTextField`), `textViewDidChangeSelection` for selection moves, `textDidBeginEditing`/`textDidEndEditing` for focus. Keep `allowsUndo = false`. On `pendingRestore` for `.advancedHTML`: set `selectedRange`, then `scrollRangeToVisible(range)` (spec §7.1/§8), then consume.

- [ ] **Step 3: `BasicFormView`** — pass `field:` and wire callbacks to the model:

```swift
MacTextField(text: text, field: fieldID, placeholder: placeholder, font: .appFieldFont,
             tabCompletion: tabCompletion,
             onEdit: { model.handleFieldEdit(fieldID, $0) },
             onSelection: { model.noteSelection(fieldID, $0) },
             onFocus: { model.noteFocus(fieldID) },
             onBlur: { model.noteBlur(fieldID) },
             pendingRestore: model.pendingRestore,
             onConsumeRestore: { model.consumePendingRestore() })
```
Thread a `FieldID` through the private `field(...)` helper for each of the four fields.

- [ ] **Step 4: `AdvancedFormView`** — wire the same for `.advancedHTML`.

- [ ] **Step 5: Build + live checkpoint (user tests).** Run the app. Verify manual plan **§2 (2.1–2.10)** and **§4 (4.1–4.4)**: continuous typing = one undo; pause never breaks; caret-move breaks; insert/delete and back/forward-delete distinct; Cut/Paste/Replace named per Task 1 findings; leaving a field preserves its groups; Advanced scrolls to the restored range. Iterate here until §2/§4 pass.

- [ ] **Step 6: Commit** once the user confirms §2/§4.

```bash
git add Obfuskoder/Views/MacTextField.swift Obfuskoder/Views/MacTextEditor.swift Obfuskoder/Views/BasicFormView.swift Obfuskoder/Views/AdvancedFormView.swift
git commit -m "Undo: rich edit capture + focus/selection restoration in field views"
```

---

## Task 7: Context routing in the command layer

**Files:**
- Create: `Obfuskoder/UndoRouter.swift`
- Modify: `Obfuskoder/AppCommands.swift`, `Obfuskoder/Views/ContentView.swift`

- [ ] **Step 1: `WindowAccessor` + `UndoRouter`.** `WindowAccessor` is a tiny `NSViewRepresentable` that captures its `view.window` and hands it to the router (records the main window). `UndoRouter` is `@MainActor @Observable`, holds `weak mainWindow`, the `AppModel`, and derives the target:

```swift
@MainActor @Observable final class UndoRouter {
    let model: AppModel
    weak var mainWindow: NSWindow?
    init(model: AppModel) { self.model = model }

    private var auxTextView: NSTextView? {
        // A focused editable text view whose NATIVE undo is live (aux fields).
        // Main-form field editors have allowsUndo=false, so they're excluded.
        guard let tv = NSApp.keyWindow?.firstResponder as? NSTextView, tv.allowsUndo else { return nil }
        return tv
    }
    private var isMainFormContext: Bool {
        guard let key = NSApp.keyWindow, key == mainWindow, mainWindow?.attachedSheet == nil else { return false }
        return true
    }

    var canUndo: Bool { auxTextView?.undoManager?.canUndo ?? (isMainFormContext && model.canUndo) }
    var canRedo: Bool { auxTextView?.undoManager?.canRedo ?? (isMainFormContext && model.canRedo) }
    var undoTitle: String {
        if let um = auxTextView?.undoManager { return um.undoMenuItemTitle }
        return isMainFormContext ? model.undoTitle : "Undo"
    }
    var redoTitle: String {
        if let um = auxTextView?.undoManager { return um.redoMenuItemTitle }
        return isMainFormContext ? model.redoTitle : "Redo"
    }
    func performUndo() {
        if let um = auxTextView?.undoManager { if um.canUndo { um.undo() }; return }
        if isMainFormContext { model.undo() }
    }
    func performRedo() {
        if let um = auxTextView?.undoManager { if um.canRedo { um.redo() }; return }
        if isMainFormContext { model.redo() }
    }
    func refresh() { /* touch an observed token to re-render the Edit menu */ }
}
```
Add an observed `refreshTick` Int the router bumps from key-window / menu-tracking notifications so SwiftUI re-renders titles (spec §2, §10.7).

- [ ] **Step 2: `AppCommands`** — replace the `.undoRedo` group to target the router; make it own the router (inject alongside `model`). Mode toggles call `model.switchMode(to:)` instead of setting `model.form.mode` directly:

```swift
CommandGroup(replacing: .undoRedo) {
    Button(router.undoTitle) { router.performUndo() }
        .keyboardShortcut("z", modifiers: .command).disabled(!router.canUndo)
    Button(router.redoTitle) { router.performRedo() }
        .keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!router.canRedo)
}
```
Update `modeBinding` setter → `model.switchMode(to: mode)`.

- [ ] **Step 3: `ContentView`** — add `WindowAccessor` (background of the split view) to record the main window into the router; change the `ModePicker` binding to route through `model.switchMode(to:)`; register key-window/menu-tracking observers that call `router.refresh()`. Remove the now-redundant `.onChange(of: model.form.mode) { model.refreshUndoState() }` if `switchMode` already refreshes.

- [ ] **Step 4: Build + live checkpoint (user tests).** Verify manual plan **§8 (mode isolation)**, **§9 (redo invalidation)**, and **§10 (sheets/Settings/key-window)**: in a Save/Manage sheet name field `⌘Z` edits the field, not the form; with no aux action available Undo is disabled (not hitting the form); Settings fallback field `⌘Z` targets it; Help window disables both; returning to the main window restores the active mode's titles. Iterate until §8–§10 pass.

- [ ] **Step 5: Commit.**

```bash
git add Obfuskoder/UndoRouter.swift Obfuskoder/AppCommands.swift Obfuskoder/Views/ContentView.swift
git commit -m "Undo: context routing across key window, sheets, and Settings"
```

---

## Task 8: Form-operation & completion specifics

**Files:**
- Modify: `Obfuskoder/AppModel.swift`, `Obfuskoder/Views/MacTextField.swift`

- [ ] **Step 1: Complete Link Text (§7.2).** In `MacTextField`'s Tab-completion path, emit an `onEdit` whose `before` = "" (empty stored link text), `after` = the accepted literal, `command: .completeLinkText`. Confirm `handleFieldEdit` registers it as a discrete `Complete Link Text` action, undo restores empty (ghost reappears), redo restores the literal.

- [ ] **Step 2: Clear focus (§7.3).** Verify `clearActiveForm`'s `undoFocus` restores the most-recently-focused field + its selection; redo focuses the mode's first field with an empty-content caret. Fix `lastSelection` capture if the restored selection is wrong.

- [ ] **Step 3: Apply focus (§7.4).** Verify undo restores the destination mode's prior focus/selection; Apply and redo focus the first field without select-all.

- [ ] **Step 4: Live checkpoint (user tests).** Manual plan **§3 (Link text ghost)**, **§6 (Clear Form)**, **§7 (Apply Saved Values)**. Iterate until they pass.

- [ ] **Step 5: Commit.**

```bash
git add Obfuskoder/AppModel.swift Obfuskoder/Views/MacTextField.swift
git commit -m "Undo: Link-text completion, Clear, and Apply focus/selection behavior"
```

---

## Task 9: Full manual matrix, cleanup, finish branch

**Files:**
- Modify: `docs/MANUAL-TEST-UNDO-REDO.md` (record result), memory files, superseded-doc pointers.

- [ ] **Step 1: Full manual pass.** Execute every section of `docs/MANUAL-TEST-UNDO-REDO.md §1–§12` in a normally-launched Release-config build. Record build/macOS/date/tester and any failures in the result table. Fix failures via `superpowers:systematic-debugging` (root cause before fix); re-run the affected section.

- [ ] **Step 2: Dead-code + doc cleanup.** Confirm no references remain to the removed burst API (`noteEdit`, `beginEditBurst`, `endEditBurst`, `history`, `index`) — `grep -rn "noteEdit\|beginEditBurst\|endEditBurst" Obfuskoder`. Ensure the superseded `2026-07-10` spec/plan carry their "Superseded by 2026-07-14" banners (already added). Run `swift test` (Kit green) and a final `xcodebuild ... build`.

- [ ] **Step 3: Update memory.** In `review-fixes-branch.md`, mark FIX-3 undo as implemented-to-spec (per the 2026-07-14 design), note the pure engine lives in ObfuskoderKit, and record any Cut/Paste-on-`NSTextField` limitation from Task 1.

- [ ] **Step 4: Finish the branch.** Use `superpowers:finishing-a-development-branch` — request a whole-branch code review (`superpowers:requesting-code-review`), then merge `undo-redo` → `main` per the user's decision.

---

## Self-Review (author checklist)

- **Spec coverage:** §2→T5/T7; §3→T7; §4→T3/T5; §5→T2/T3/T8; §6→T3 (every rule has a test); §7→T4/T8; §8→T4/T6/T8; §9→T3/T5/T7; §10→T5; §11 lifetime→T5 (app-lifetime managers, no cap); §12→**deferred (documented)**; §14→T1/T6/T7/T8/T9 live gates. ✓
- **Type consistency:** `FieldID`, `TextSelection`, `EditKind`, `CommittedEdit`, `RestoreTarget`, `RawTextEdit`, `FormActionRecorder.record(mode:before:after:name:undoFocus:redoFocus:)`, `UndoGroupingEngine.ingest/endGroup` used identically across tasks. ✓
- **Placeholders:** none — pure tasks carry full test + impl code; glue tasks carry concrete code + explicit live-test checkpoints (the correct verification for runtime-only behavior). ✓
- **Known risk:** Cut/Paste distinction on `NSTextField` is gated by the Task 1 spike; the plan degrades gracefully and records the outcome. ✓
