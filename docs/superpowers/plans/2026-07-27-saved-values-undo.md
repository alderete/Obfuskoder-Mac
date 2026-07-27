# Saved Values Undo/Redo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-session undo/redo for deleting and reordering saved values in the Manage Saved Values panel, on a stack separate from the form undo.

**Architecture:** A tested core (`SavedValuesUndo` in ObfuskoderKit) wraps `PresetStore` delete/reorder and registers granular inverse operations on a `Foundation.UndoManager`. The `UndoRouter` gains a saved-values context so the Edit-menu ⌘Z/⇧⌘Z target that stack while the panel is open (native text undo still wins when a name field is focused). The panel routes its delete/reorder through the core, registers the core with the router on appear, and animates a restored row.

**Tech Stack:** Swift 6, SwiftUI + AppKit, `Foundation.UndoManager`, Swift Testing.

## Global Constraints

- Platform macOS 14+; Swift 6 language mode. New Kit code is `@MainActor` where it touches `PresetStore` (which is `@MainActor @Observable`).
- App targets are **warnings-as-errors** (`SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`): app-side code (Tasks 3–5) must compile with zero warnings.
- Undo action titles use curly quotes exactly like `UIStrings.undoApply`: `Delete \u{201C}<name>\u{201D}`, `Move \u{201C}<name>\u{201D}`.
- Scope: **delete + reorder only**. Never register rename or create on this stack (rename keeps native field undo; create isn't undoable).
- Lifetime: **per Manage-panel session** — the core is created when the panel opens and `reset()` on close; reachable only while the panel is open.
- The restore animation honors **Reduce Motion** (`@Environment(\.accessibilityReduceMotion)`): no animation when enabled.
- Tests: Swift Testing (`import Testing`, `@Test`, `#expect`/`#require`, `@MainActor`), using the existing `tempStore()` helper pattern in `PresetStoreTests.swift`.

---

### Task 1: PresetStore insert + setOrder

**Files:**
- Modify: `ObfuskoderKit/Sources/ObfuskoderKit/PresetStore.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/PresetStoreTests.swift`

**Interfaces:**
- Consumes: existing `PresetStore` (`presets: [Preset]`, `save`, `delete`, `move`, private `persist`).
- Produces:
  - `func insert(_ preset: Preset, at index: Int)` — inserts `preset` at `min(max(index,0), presets.count)`, persists; does NOT enforce name uniqueness.
  - `func setOrder(_ ids: [UUID])` — reorders `presets` so ids appear in the given order; ids not present are ignored; presets whose id is absent from `ids` are appended in their current relative order; persists.

- [ ] **Step 1: Write failing tests**

Add to `PresetStoreTests.swift`:

```swift
@MainActor @Test func insertRestoresAtIndex() throws {
    let (store, _) = tempStore()
    let a = try store.save(name: "A", payload: .advanced("a"))
    let b = try store.save(name: "B", payload: .advanced("b"))
    let c = try store.save(name: "C", payload: .advanced("c"))
    try store.delete(id: b.id)
    #expect(store.presets.map(\.id) == [a.id, c.id])
    store.insert(b, at: 1)
    #expect(store.presets.map(\.id) == [a.id, b.id, c.id])
}

@MainActor @Test func insertClampsOutOfRangeIndex() throws {
    let (store, _) = tempStore()
    let a = try store.save(name: "A", payload: .advanced("a"))
    let b = Preset(name: "B", payload: .advanced("b"))
    store.insert(b, at: 99)
    #expect(store.presets.map(\.id) == [a.id, b.id])
}

@MainActor @Test func insertPersists() throws {
    let (store, url) = tempStore()
    let a = Preset(name: "A", payload: .advanced("a"))
    store.insert(a, at: 0)
    let reloaded = PresetStore(fileURL: url)
    #expect(reloaded.presets.map(\.id) == [a.id])
}

@MainActor @Test func setOrderReordersById() throws {
    let (store, _) = tempStore()
    let a = try store.save(name: "A", payload: .advanced("a"))
    let b = try store.save(name: "B", payload: .advanced("b"))
    let c = try store.save(name: "C", payload: .advanced("c"))
    store.setOrder([c.id, a.id, b.id])
    #expect(store.presets.map(\.id) == [c.id, a.id, b.id])
}

@MainActor @Test func setOrderIgnoresMissingAndAppendsUnlisted() throws {
    let (store, _) = tempStore()
    let a = try store.save(name: "A", payload: .advanced("a"))
    let b = try store.save(name: "B", payload: .advanced("b"))
    // Unknown id ignored; unlisted `b` appended in current order.
    store.setOrder([UUID(), a.id])
    #expect(store.presets.map(\.id) == [a.id, b.id])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ObfuskoderKit && swift test --filter PresetStoreTests`
Expected: FAIL — `insert`/`setOrder` are not members of `PresetStore`.

- [ ] **Step 3: Implement**

Add to `PresetStore.swift` (after `move(...)`):

```swift
/// Re-insert a preset at a given index (used by delete-undo). Clamps the
/// index; does NOT enforce name uniqueness — this is a restore.
public func insert(_ preset: Preset, at index: Int) {
    var updated = presets
    let clamped = min(max(index, 0), updated.count)
    updated.insert(preset, at: clamped)
    do { try persist(updated); presets = updated } catch { }
}

/// Reorder to the given id sequence (used by reorder-undo/redo). Ids not
/// present are ignored; presets absent from `ids` keep their current relative
/// order, appended after the listed ones.
public func setOrder(_ ids: [UUID]) {
    let byId = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0) })
    var ordered = ids.compactMap { byId[$0] }
    let listed = Set(ids)
    ordered += presets.filter { !listed.contains($0.id) }
    do { try persist(ordered); presets = ordered } catch { }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ObfuskoderKit && swift test --filter PresetStoreTests`
Expected: PASS (all, including the pre-existing ones).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/PresetStore.swift ObfuskoderKit/Tests/ObfuskoderKitTests/PresetStoreTests.swift
git commit -m "PresetStore: add insert(at:) and setOrder(_:) for undo support"
```

---

### Task 2: SavedValuesUndo core

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/SavedValuesUndo.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/SavedValuesUndoTests.swift`

**Interfaces:**
- Consumes: `PresetStore` (`presets`, `delete(id:)`, `move(fromOffsets:toOffset:)`, `insert(_:at:)`, `setOrder(_:)` from Task 1).
- Produces:
  - `final class SavedValuesUndo` (`@MainActor`)
  - `init(store: PresetStore, undoManager: UndoManager = UndoManager())`
  - `func delete(id: UUID, actionName: String) throws`
  - `func move(fromOffsets source: IndexSet, toOffset destination: Int, actionName: String)`
  - `var canUndo: Bool`, `var canRedo: Bool`
  - `var undoMenuItemTitle: String`, `var redoMenuItemTitle: String`
  - `func undo()`, `func redo()`, `func reset()`

- [ ] **Step 1: Write failing tests**

Create `SavedValuesUndoTests.swift`:

```swift
import Testing
import Foundation
@testable import ObfuskoderKit

@MainActor
private func seeded() throws -> (PresetStore, SavedValuesUndo, [Preset]) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("obfuskoder-svu-\(UUID().uuidString)", isDirectory: true)
    let store = PresetStore(fileURL: dir.appendingPathComponent("presets.json"))
    let a = try store.save(name: "A", payload: .advanced("a"))
    let b = try store.save(name: "B", payload: .advanced("b"))
    let c = try store.save(name: "C", payload: .advanced("c"))
    return (store, SavedValuesUndo(store: store), [a, b, c])
}

@MainActor @Test func deleteUndoRestoresAtIndex() throws {
    let (store, undo, p) = try seeded()
    try undo.delete(id: p[1].id, actionName: "Delete B")
    #expect(store.presets.map(\.id) == [p[0].id, p[2].id])
    #expect(undo.canUndo)
    undo.undo()
    #expect(store.presets.map(\.id) == [p[0].id, p[1].id, p[2].id])
}

@MainActor @Test func deleteRedoDeletesAgain() throws {
    let (store, undo, p) = try seeded()
    try undo.delete(id: p[1].id, actionName: "Delete B")
    undo.undo()
    #expect(undo.canRedo)
    undo.redo()
    #expect(store.presets.map(\.id) == [p[0].id, p[2].id])
}

@MainActor @Test func reorderUndoRestoresOrder() throws {
    let (store, undo, p) = try seeded()
    undo.move(fromOffsets: IndexSet(integer: 0), toOffset: 3, actionName: "Move A") // A to end
    #expect(store.presets.map(\.id) == [p[1].id, p[2].id, p[0].id])
    undo.undo()
    #expect(store.presets.map(\.id) == [p[0].id, p[1].id, p[2].id])
    undo.redo()
    #expect(store.presets.map(\.id) == [p[1].id, p[2].id, p[0].id])
}

@MainActor @Test func renameBetweenDeleteAndUndoIsPreserved() throws {
    let (store, undo, p) = try seeded()
    try undo.delete(id: p[0].id, actionName: "Delete A")   // delete A
    try store.rename(id: p[2].id, to: "C-renamed")          // rename C (native path, not on the stack)
    undo.undo()                                             // undo the delete of A
    #expect(store.presets.first(where: { $0.id == p[2].id })?.name == "C-renamed")
    #expect(store.presets.contains { $0.id == p[0].id })
}

@MainActor @Test func emptyStackIsNoOp() throws {
    let (_, undo, _) = try seeded()
    #expect(!undo.canUndo)
    #expect(!undo.canRedo)
    undo.undo() // no crash
    undo.redo() // no crash
}

@MainActor @Test func resetClearsStack() throws {
    let (_, undo, p) = try seeded()
    try undo.delete(id: p[0].id, actionName: "Delete A")
    #expect(undo.canUndo)
    undo.reset()
    #expect(!undo.canUndo)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ObfuskoderKit && swift test --filter SavedValuesUndoTests`
Expected: FAIL — `SavedValuesUndo` does not exist.

- [ ] **Step 3: Implement**

Create `SavedValuesUndo.swift`:

```swift
import Foundation

/// Per-session undo/redo for saved-value DELETE and REORDER, on a stack
/// separate from the form undo. Registers granular inverse operations so
/// interleaved renames (which use native field undo) are never clobbered.
/// The caller supplies the localized action name.
@MainActor
public final class SavedValuesUndo {
    private let store: PresetStore
    private let undoManager: UndoManager

    public init(store: PresetStore, undoManager: UndoManager = UndoManager()) {
        self.store = store
        self.undoManager = undoManager
    }

    public var canUndo: Bool { undoManager.canUndo }
    public var canRedo: Bool { undoManager.canRedo }
    public var undoMenuItemTitle: String { undoManager.undoMenuItemTitle }
    public var redoMenuItemTitle: String { undoManager.redoMenuItemTitle }

    public func undo() { if undoManager.canUndo { undoManager.undo() } }
    public func redo() { if undoManager.canRedo { undoManager.redo() } }
    public func reset() { undoManager.removeAllActions() }

    // MARK: Delete

    public func delete(id: UUID, actionName: String) throws {
        guard let index = store.presets.firstIndex(where: { $0.id == id }) else {
            throw PresetError.notFound
        }
        let preset = store.presets[index]
        try store.delete(id: id)
        registerReinsert(preset: preset, index: index, name: actionName)
    }

    /// State just became "deleted"; register the UNDO that re-inserts.
    private func registerReinsert(preset: Preset, index: Int, name: String) {
        undoManager.setActionName(name)
        undoManager.registerUndo(withTarget: self) { target in
            target.store.insert(preset, at: index)
            target.registerRedelete(preset: preset, index: index, name: name)
        }
    }

    /// State just became "re-inserted" (an undo); register the REDO that deletes.
    private func registerRedelete(preset: Preset, index: Int, name: String) {
        undoManager.setActionName(name)
        undoManager.registerUndo(withTarget: self) { target in
            try? target.store.delete(id: preset.id)
            target.registerReinsert(preset: preset, index: index, name: name)
        }
    }

    // MARK: Reorder

    public func move(fromOffsets source: IndexSet, toOffset destination: Int, actionName: String) {
        let previous = store.presets.map(\.id)
        store.move(fromOffsets: source, toOffset: destination)
        let current = store.presets.map(\.id)
        registerReorder(restore: previous, reapply: current, name: actionName)
    }

    /// Order just changed; register the UNDO that restores `restore`, whose
    /// handler in turn sets up the REDO that restores `reapply`.
    private func registerReorder(restore: [UUID], reapply: [UUID], name: String) {
        undoManager.setActionName(name)
        undoManager.registerUndo(withTarget: self) { target in
            target.store.setOrder(restore)
            target.registerReorder(restore: reapply, reapply: restore, name: name)
        }
    }
}
```

Note on grouping: the default `groupsByEvent = true` is intentional — each user action (delete / drag / Move Up-Down / a menu undo) is a single run-loop event, so it forms exactly one undo step. No explicit `beginUndoGrouping` needed (unlike the form's coalescing engine).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ObfuskoderKit && swift test --filter SavedValuesUndoTests`
Expected: PASS (all six).

- [ ] **Step 5: Full Kit suite + commit**

Run: `cd ObfuskoderKit && swift test`
Expected: PASS (all).

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/SavedValuesUndo.swift ObfuskoderKit/Tests/ObfuskoderKitTests/SavedValuesUndoTests.swift
git commit -m "SavedValuesUndo: tested core for delete/reorder undo (ObfuskoderKit)"
```

---

### Task 3: UndoRouter saved-values context

**Files:**
- Modify: `Obfuskoder/UndoRouter.swift`

**Interfaces:**
- Consumes: `SavedValuesUndo` (Task 2) — `canUndo/canRedo/undoMenuItemTitle/redoMenuItemTitle/undo()/redo()`.
- Produces: `UndoRouter.savedValuesUndo: SavedValuesUndo?` (set/cleared by the panel in Task 4); routing that prefers a focused aux field, then saved-values, then the main form.

**Verification:** runtime routing is not unit-testable (like the existing form router); verified by a clean build here and the manual gate in Task 5.

- [ ] **Step 1: Add the property and import**

At the top of `UndoRouter.swift` ensure `import ObfuskoderKit`. Add inside `UndoRouter` near `mainWindow`:

```swift
/// The Manage Saved Values panel's per-session undo stack, set while that
/// panel is open (Task 4). Non-nil ⇒ the panel is the active context.
@ObservationIgnored weak var savedValuesUndo: SavedValuesUndo?
```

- [ ] **Step 2: Route to it (aux field first, then saved-values, then form)**

Update each computed property / method to insert a saved-values branch between the aux-field branch and the main-form branch. For example `canUndo`:

```swift
var canUndo: Bool {
    _ = tick
    if let um = auxTextView?.undoManager { return um.canUndo }
    if let sv = savedValuesUndo { return sv.canUndo }
    return isMainFormContext && model.canUndo
}
```

Apply the same pattern to `canRedo` (`sv.canRedo`), `undoTitle` (`sv.undoMenuItemTitle`), `redoTitle` (`sv.redoMenuItemTitle`), `performUndo` (`sv.undo(); return`), and `performRedo` (`sv.redo(); return`). Concretely for the actions:

```swift
func performUndo() {
    if let um = auxTextView?.undoManager { if um.canUndo { um.undo() }; return }
    if let sv = savedValuesUndo { sv.undo(); return }
    if isMainFormContext { model.undo() }
}
func performRedo() {
    if let um = auxTextView?.undoManager { if um.canRedo { um.redo() }; return }
    if let sv = savedValuesUndo { sv.redo(); return }
    if isMainFormContext { model.redo() }
}
```

- [ ] **Step 3: Refresh menu state on saved-values changes**

Add these three names to the `names` array in `init` so `tick` bumps when the saved-values manager registers/undoes/redoes (they also fire for the form managers — harmless):

```swift
.NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange, .NSUndoManagerDidCloseUndoGroup,
```

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`, zero warnings (warnings-as-errors is on).

- [ ] **Step 5: Commit**

```bash
git add Obfuskoder/UndoRouter.swift
git commit -m "UndoRouter: route Undo/Redo to the saved-values stack when its panel is active"
```

---

### Task 4: Manage panel wiring + action-name strings

**Files:**
- Modify: `Obfuskoder/Views/ManagePresetsSheet.swift`
- Modify: `Obfuskoder/Strings.swift`

**Interfaces:**
- Consumes: `SavedValuesUndo` (Task 2); `UndoRouter.savedValuesUndo` (Task 3).
- Produces: the panel performs delete/reorder through a session `SavedValuesUndo`, registered with the router while open. Rename is unchanged.

**Verification:** build + manual (delete/reorder → ⌘Z restores; name-field ⌘Z still edits the name).

- [ ] **Step 1: Add action-name strings**

In `Strings.swift` (near `undoApply`), add:

```swift
static func savedValueDeleteAction(name: String) -> String {
    String(localized: "Delete \u{201C}\(name)\u{201D}")
}
static func savedValueMoveAction(name: String) -> String {
    String(localized: "Move \u{201C}\(name)\u{201D}")
}
```

- [ ] **Step 2: Create a session SavedValuesUndo and register it**

In `ManagePresetsSheet`, add the environment router, a session undo object built from the injected store, and register/reset on appear/disappear:

```swift
@Environment(UndoRouter.self) private var router
@State private var undo: SavedValuesUndo

init(store: PresetStore) {
    self.store = store
    _undo = State(initialValue: SavedValuesUndo(store: store))
}
```

Add to the outer `VStack` in `body` (alongside the existing modifiers):

```swift
.onAppear { router.savedValuesUndo = undo }
.onDisappear { router.savedValuesUndo = nil; undo.reset() }
```

If the router is not found in the sheet's environment at runtime, pass it explicitly from `SavedValuesBar` when presenting the sheet; verify during the manual step.

- [ ] **Step 3: Route delete and reorder through `undo`**

Replace the direct store calls:

- In `PresetRow.deletePreset()` the call is `store.delete(id:)`. Route deletion through the panel instead. Change the row's delete to call a closure passed from `ManagePresetsSheet` that runs:

```swift
try? undo.delete(id: preset.id, actionName: UIStrings.savedValueDeleteAction(name: preset.name))
```

- In `ManagePresetsSheet.move(from:to:)`, replace `store.move(fromOffsets:toOffset:)` with:

```swift
let movedName = store.presets[source].name
undo.move(fromOffsets: IndexSet(integer: source),
          toOffset: target > source ? target + 1 : target,
          actionName: UIStrings.savedValueMoveAction(name: movedName))
```

(Keep the existing offset adjustment logic; only the final mutating call changes.) Rename (`commitRename`) is left calling `store.rename` directly — it stays on native field undo.

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 5: Manual smoke check**

Run the app, open Manage Saved Values:
- Delete a preset, press ⌘Z → it comes back at its position; ⇧⌘Z deletes again.
- Drag-reorder (and Move Up/Down) → ⌘Z restores order.
- Edit a name field → ⌘Z edits the text (native), not the delete/reorder.
- Edit menu shows **Undo Delete "Name"** / **Undo Move "Name"**; disabled when the stack is empty; disabled after closing/reopening the panel.

- [ ] **Step 6: Commit**

```bash
git add Obfuskoder/Views/ManagePresetsSheet.swift Obfuskoder/Strings.swift
git commit -m "Manage Saved Values: route delete/reorder through the undo stack"
```

---

### Task 5: Restore animation + manual-test doc

**Files:**
- Modify: `Obfuskoder/Views/ManagePresetsSheet.swift`
- Modify: `docs/MANUAL-TEST-UNDO-REDO.md`

**Interfaces:**
- Consumes: the working wiring from Task 4.
- Produces: a squeeze-in insertion animation on the preset list (Reduce-Motion aware) and the filled-in §10.4 manual checklist.

**Verification:** build + manual (restore animates; instant under Reduce Motion).

- [ ] **Step 1: Add the Reduce-Motion environment and animate the list**

In `ManagePresetsSheet` add:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

On the rows' `ForEach` container (the `VStack(spacing: 0)` inside the `ScrollView`), drive an implicit animation off the preset id-list and give each row an insertion transition so a restored row squeezes into place while the others make room:

```swift
.animation(reduceMotion ? nil : .default, value: store.presets.map(\.id))
```

And on each row view (in `row(_:at:)`), add:

```swift
.transition(.asymmetric(
    insertion: .scale(scale: 0.1, anchor: .top).combined(with: .opacity),
    removal: .opacity))
```

(The existing drag-reorder `.animation(...)` modifiers on the row stay; they animate reorder-undo movement. Verify they don't visually fight the insertion transition during the manual step — if they do, scope the new `.animation` to insertions only by keying it to `store.presets.count`.)

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`, zero warnings.

- [ ] **Step 3: Manual check**

- Delete a preset, ⌘Z → the row animates in, squeezing into its space; rows below shift down smoothly.
- System Settings → Accessibility → Display → Reduce Motion ON → the restore is instant (no animation).

- [ ] **Step 4: Fill in the manual-test doc**

Replace the §10.4 placeholder line in `docs/MANUAL-TEST-UNDO-REDO.md` with concrete cases:

```markdown
- [ ] 10.4 In Manage Saved Values (panel-session undo, separate stack):
      delete a preset → ⌘Z restores it (animated squeeze-in) at its original
      position; ⇧⌘Z deletes again. Reorder (drag and Move Up/Down) → ⌘Z restores
      order; ⇧⌘Z re-applies. Edit menu shows Undo Delete "Name" / Undo Move
      "Name", disabled when empty. While a name field is focused, ⌘Z edits the
      name (native), not the list. Closing and reopening the panel starts empty.
      With Reduce Motion on, restores are instant.
```

- [ ] **Step 5: Commit**

```bash
git add Obfuskoder/Views/ManagePresetsSheet.swift docs/MANUAL-TEST-UNDO-REDO.md
git commit -m "Manage Saved Values: squeeze-in restore animation + manual test"
```

---

## Self-Review

**Spec coverage:** delete undo/redo (Tasks 1,2,4), reorder undo/redo (Tasks 1,2,4), separate per-session stack (Task 2 lifetime + Task 4 register/reset), granular inverses / rename-safety (Task 2 tests), routing with name-field priority (Task 3), named titles (Task 4 strings), squeeze-in animation + Reduce Motion (Task 5), manual §10.4 (Task 5). Out-of-scope items (create, rename) are explicitly left untouched. All covered.

**Placeholder scan:** none — every code and test step is concrete.

**Type consistency:** `insert(_:at:)`, `setOrder(_:)`, `SavedValuesUndo(store:undoManager:)`, `delete(id:actionName:)`, `move(fromOffsets:toOffset:actionName:)`, `savedValuesUndo`, `savedValueDeleteAction(name:)`, `savedValueMoveAction(name:)` are used identically across tasks.
