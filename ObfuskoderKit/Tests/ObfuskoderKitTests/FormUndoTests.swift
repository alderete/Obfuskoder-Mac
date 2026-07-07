import Testing
import Foundation
@testable import ObfuskoderKit

@MainActor
private final class FormBox: FormUndoable {
    var undoableForm: FormState
    init(_ initial: FormState) { undoableForm = initial }
}

private func state(_ s: String) -> FormState { FormState(mode: .advanced, advanced: s) }

@MainActor @Test func changeIsUndoableAndRedoable() {
    let box = FormBox(state("zero"))
    let mgr = UndoManager()
    FormUndo.change(box, to: state("one"), actionName: "Edit", undoManager: mgr)
    #expect(box.undoableForm == state("one"))
    #expect(mgr.canUndo)

    mgr.undo()
    #expect(box.undoableForm == state("zero"))
    #expect(mgr.canRedo)      // undo/redo replay must NOT clear the stack

    mgr.redo()
    #expect(box.undoableForm == state("one"))
}

// The recursive re-registration must survive repeated undo/redo ping-pong,
// not just a single round trip.
@MainActor @Test func survivesRepeatedUndoRedo() {
    let box = FormBox(state("zero"))
    let mgr = UndoManager()
    FormUndo.change(box, to: state("one"), actionName: "Edit", undoManager: mgr)
    for _ in 0..<3 {
        mgr.undo()
        #expect(box.undoableForm == state("zero"))
        #expect(mgr.canRedo)
        mgr.redo()
        #expect(box.undoableForm == state("one"))
        #expect(mgr.canUndo)
    }
}

// A top-level form change must clear any fine-grained text-edit undo already on
// the manager, so those stale actions (whose character ranges no longer match
// the wholesale-replaced content) can never replay and corrupt the text.
@MainActor @Test func topLevelChangeClearsStaleActions() {
    let box = FormBox(state("zero"))
    let mgr = UndoManager()
    // Stand in for a pending NSTextView text-edit undo action.
    mgr.registerUndo(withTarget: box) { $0.undoableForm = state("STALE") }
    #expect(mgr.canUndo)

    FormUndo.change(box, to: state("one"), actionName: "Clear", undoManager: mgr)
    mgr.undo()
    #expect(box.undoableForm == state("zero"))   // undid the form change
    #expect(!mgr.canUndo)                         // the STALE action is gone
}

@MainActor @Test func eachTopLevelChangeReplacesTheStack() {
    let box = FormBox(state("zero"))
    let mgr = UndoManager()
    FormUndo.change(box, to: state("one"), actionName: "A", undoManager: mgr)
    FormUndo.change(box, to: state("two"), actionName: "B", undoManager: mgr)
    mgr.undo()
    #expect(box.undoableForm == state("one"))
    #expect(!mgr.canUndo)   // the first change's restore was cleared by the second
}

@MainActor @Test func nilUndoManagerStillPerformsTheChange() {
    let box = FormBox(state("zero"))
    FormUndo.change(box, to: state("one"), actionName: "Edit", undoManager: nil)
    #expect(box.undoableForm == state("one"))
}

// NOTE: `FormUndo.registerRestore` captures `[weak undoManager]` to avoid a
// manager → action → manager retain cycle (see FormUndo.swift). This property
// resists a reliable automated test: it is observable only through the
// manager *deallocating*, and an UndoManager with `groupsByEvent == true`
// (required for `change()` to register without manual grouping) is retained by
// a run-loop observer whose release depends on draining a run loop the
// parallel test runner does not reliably provide to a @MainActor test — so a
// dealloc assertion is flaky. Verified manually instead: flipping the capture
// to strong keeps a `weak` reference non-nil after an autoreleasepool + bounded
// run-loop drain, while the weak capture releases it.
