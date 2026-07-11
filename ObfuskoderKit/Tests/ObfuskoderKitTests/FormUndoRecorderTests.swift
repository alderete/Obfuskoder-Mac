import Testing
import Foundation
import ObfuskoderKit

// NSUndoManager auto-groups by run-loop event; tests have no run loop, so we
// disable that and group each action explicitly (the standard NSUndoManager
// test pattern). In the app, event grouping does this automatically.

@MainActor
@Test func undoRestoresPriorContentAndKeepsMode() {
    var form = FormState(mode: .basic, basic: BasicFields(email: "a@b.com"))
    let um = UndoManager()
    um.groupsByEvent = false
    let rec = FormUndoRecorder(undoManager: um, get: { form }, set: { form = $0 })

    let previous = form
    um.beginUndoGrouping()
    form.clearActive()
    rec.record(previous: previous, actionName: "Clear Form")
    um.endUndoGrouping()

    #expect(form.activeIsEmpty)
    #expect(um.canUndo)

    um.undo()
    #expect(form.basic.email == "a@b.com")
    #expect(form.mode == .basic)
    #expect(um.canRedo)

    um.redo()
    #expect(form.activeIsEmpty)
}

// Applying a preset can switch mode; undo must restore the target mode's prior
// CONTENT but NOT revert the mode switch (SPEC §4/§7).
@MainActor
@Test func undoOfApplyKeepsLoadedModeButRestoresContent() {
    var form = FormState(mode: .advanced, advanced: "X")
    let um = UndoManager()            // stands in for the Basic manager (apply lands in .basic)
    um.groupsByEvent = false
    let rec = FormUndoRecorder(undoManager: um, get: { form }, set: { form = $0 })

    let previous = form
    um.beginUndoGrouping()
    form.apply(Preset(name: "P", payload: .basic(BasicFields(email: "p@x.com"))))
    rec.record(previous: previous, actionName: "Apply Saved Values")
    um.endUndoGrouping()

    #expect(form.mode == .basic && form.basic.email == "p@x.com")

    um.undo()
    #expect(form.mode == .basic)                 // mode NOT reverted to .advanced
    #expect(form.basic == BasicFields())         // basic restored to its prior (empty)
    #expect(form.advanced == "X")                // advanced content preserved
}

// A mode's undo must restore only that mode's content — never clobber the other
// mode's data (SPEC §3: independent, mode-scoped stacks).
@MainActor
@Test func undoRestoresOnlyActiveModeContent() {
    var form = FormState(mode: .basic, basic: BasicFields(email: "e@x.com"), advanced: "<p>keep</p>")
    let um = UndoManager()
    um.groupsByEvent = false
    let rec = FormUndoRecorder(undoManager: um, get: { form }, set: { form = $0 })

    let previous = form
    um.beginUndoGrouping()
    form.basic.email = "changed@x.com"
    rec.record(previous: previous, actionName: "Typing")
    um.endUndoGrouping()
    form.advanced = "<p>edited independently</p>"   // advanced changes after the basic edit

    um.undo()
    #expect(form.basic.email == "e@x.com")                 // basic restored
    #expect(form.advanced == "<p>edited independently</p>") // advanced NOT clobbered
}

@MainActor
@Test func recordSetsTheActionName() {
    var form = FormState(mode: .basic, basic: BasicFields(email: "a@b.com"))
    let um = UndoManager()
    um.groupsByEvent = false
    let rec = FormUndoRecorder(undoManager: um, get: { form }, set: { form = $0 })

    let previous = form
    um.beginUndoGrouping()
    form.clearActive()
    rec.record(previous: previous, actionName: "Clear Form")
    um.endUndoGrouping()

    #expect(um.undoActionName == "Clear Form")
}
