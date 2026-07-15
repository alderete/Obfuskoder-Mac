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

@MainActor
@Test func undoRestoresSliceFocusAndName() {
    let sink = Sink(FormState(mode: .basic, basic: BasicFields(email: "a@b.com"), advanced: "<keep>"))
    let um = UndoManager(); um.groupsByEvent = false
    let rec = FormActionRecorder(undoManager: um, get: { sink.form }, apply: sink.apply)

    let before = sink.form
    sink.form.basic.email = "changed@b.com"
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

// Applying a preset can switch mode; undo restores the destination mode's prior
// content but must NOT revert the mode switch or touch the source mode (spec §7.4).
@MainActor
@Test func undoOfApplyKeepsModeRestoresDestinationSlice() {
    let sink = Sink(FormState(mode: .advanced, advanced: "X"))
    let um = UndoManager(); um.groupsByEvent = false
    let rec = FormActionRecorder(undoManager: um, get: { sink.form }, apply: sink.apply)

    let before = sink.form
    sink.form.apply(Preset(name: "P", payload: .basic(BasicFields(email: "p@x.com"))))
    um.beginUndoGrouping()
    rec.record(mode: .basic, before: before, after: sink.form, name: "Apply “P”",
               undoFocus: RestoreTarget(field: .email, selection: TextSelection(location: 0)),
               redoFocus: RestoreTarget(field: .email, selection: TextSelection(location: 0)))
    um.endUndoGrouping()
    #expect(sink.form.mode == .basic && sink.form.basic.email == "p@x.com")

    um.undo()
    #expect(sink.form.mode == .basic)              // mode switch NOT reverted
    #expect(sink.form.basic == BasicFields())      // basic slice restored to prior empty
    #expect(sink.form.advanced == "X")             // advanced untouched
}

// A mode's undo restores only that mode's content — never clobbering the other
// mode's data edited in between (spec §3/§4: independent, mode-scoped stacks).
@MainActor
@Test func undoRestoresOnlyActiveModeContent() {
    let sink = Sink(FormState(mode: .basic, basic: BasicFields(email: "e@x.com"), advanced: "<p>keep</p>"))
    let um = UndoManager(); um.groupsByEvent = false
    let rec = FormActionRecorder(undoManager: um, get: { sink.form }, apply: sink.apply)

    let before = sink.form
    sink.form.basic.email = "changed@x.com"
    um.beginUndoGrouping()
    rec.record(mode: .basic, before: before, after: sink.form, name: "Typing",
               undoFocus: nil, redoFocus: nil)
    um.endUndoGrouping()
    sink.form.advanced = "<p>edited independently</p>"   // advanced changes after the basic edit

    um.undo()
    #expect(sink.form.basic.email == "e@x.com")                  // basic restored
    #expect(sink.form.advanced == "<p>edited independently</p>") // advanced NOT clobbered
}
