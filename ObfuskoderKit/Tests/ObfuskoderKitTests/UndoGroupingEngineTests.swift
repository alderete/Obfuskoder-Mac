import Testing
import ObfuskoderKit

private func typing(_ field: FieldID, _ before: String, _ after: String,
                    at loc: Int) -> TextEditEvent {
    TextEditEvent(field: field, kind: .insert, before: before,
                  beforeSelection: EditSelection(location: loc),
                  after: after, afterSelection: EditSelection(location: loc + (after.count - before.count)))
}

@Test func continuousTypingIsOneGroup() {   // manual §2.1 / §2.2 (pause never breaks)
    var e = UndoGroupingEngine()
    #expect(e.ingest(typing(.email, "", "a", at: 0)).isEmpty)
    #expect(e.ingest(typing(.email, "a", "ab", at: 1)).isEmpty)
    #expect(e.ingest(typing(.email, "ab", "abc", at: 2)).isEmpty)
    let c = e.endGroup()
    #expect(c?.before == "" && c?.after == "abc" && c?.kind == .insert)
}

@Test func caretMoveEndsGroup() {            // manual §2.3
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "", "abcdef", at: 0))
    let first = e.endGroup()                                // caret move ⇒ close
    #expect(first?.after == "abcdef")
    // Type XYZ at a new location; its beforeSelection ≠ the prior group's afterSelection.
    let x = TextEditEvent(field: .email, kind: .insert, before: "abcdef",
                          beforeSelection: EditSelection(location: 3),
                          after: "abcXYZdef", afterSelection: EditSelection(location: 6))
    #expect(e.ingest(x).isEmpty)
    #expect(e.endGroup()?.after == "abcXYZdef")
}

@Test func caretMoveMidStreamClosesWithoutExplicitEnd() {
    // Even without an explicit endGroup, a non-contiguous next edit closes the run.
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "", "abc", at: 0))          // caret now at 3
    let jump = TextEditEvent(field: .email, kind: .insert, before: "abc",
                             beforeSelection: EditSelection(location: 0),   // caret jumped to 0
                             after: "Xabc", afterSelection: EditSelection(location: 1))
    let committed = e.ingest(jump)
    #expect(committed.count == 1 && committed[0].after == "abc")
}

@Test func insertThenDeleteAreTwoGroups() {  // manual §2.4
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "", "abc", at: 0))
    let del = TextEditEvent(field: .email, kind: .deleteBackward, before: "abc",
                            beforeSelection: EditSelection(location: 3),
                            after: "ab", afterSelection: EditSelection(location: 2))
    let committed = e.ingest(del)             // kind change closes the typing group
    #expect(committed.count == 1 && committed[0].after == "abc" && committed[0].kind == .insert)
    #expect(e.endGroup()?.kind == .deleteBackward)
}

@Test func backwardAndForwardDeleteAreDistinct() {  // manual §2.5
    var e = UndoGroupingEngine()
    let back = TextEditEvent(field: .email, kind: .deleteBackward, before: "abcd",
                             beforeSelection: EditSelection(location: 4),
                             after: "abc", afterSelection: EditSelection(location: 3))
    _ = e.ingest(back)
    let fwd = TextEditEvent(field: .email, kind: .deleteForward, before: "abc",
                            beforeSelection: EditSelection(location: 0),
                            after: "bc", afterSelection: EditSelection(location: 0))
    let committed = e.ingest(fwd)
    #expect(committed.count == 1 && committed[0].kind == .deleteBackward)
}

@Test func discreteActionIsItsOwnGroupAndClosesPrior() {  // manual §2.6/§2.7/§2.8
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "", "ab", at: 0))
    let paste = TextEditEvent(field: .email, kind: .paste, before: "ab",
                              beforeSelection: EditSelection(location: 2),
                              after: "abXYZ", afterSelection: EditSelection(location: 5))
    let committed = e.ingest(paste)
    #expect(committed.count == 2)                 // prior typing + the paste
    #expect(committed[0].kind == .insert && committed[1].kind == .paste)
    #expect(!e.hasOpenGroupPublic)                // a discrete edit leaves nothing open
}

@Test func fieldChangeEndsGroupButKeepsBoth() {   // manual §2.9
    var e = UndoGroupingEngine()
    _ = e.ingest(typing(.email, "", "x", at: 0))
    let subj = typing(.subject, "", "y", at: 0)   // different field
    let committed = e.ingest(subj)
    #expect(committed.count == 1 && committed[0].field == .email)
    #expect(e.endGroup()?.field == .subject)
}

@Test func returnToStartRecordsNothing() {        // manual §2.10 / §9
    var e = UndoGroupingEngine()
    let noop = TextEditEvent(field: .email, kind: .replace, before: "abc",
                             beforeSelection: EditSelection(location: 0, length: 3),
                             after: "abc", afterSelection: EditSelection(location: 3))
    #expect(e.ingest(noop).isEmpty)               // discrete replace, before == after ⇒ nothing
}

@Test func openGroupStateForMenu() {
    var e = UndoGroupingEngine()
    #expect(e.openGroupKind == nil && !e.openGroupHasNetChange)
    _ = e.ingest(typing(.email, "", "a", at: 0))
    #expect(e.openGroupKind == .insert && e.openGroupHasNetChange)
    _ = e.endGroup()
    #expect(e.openGroupKind == nil)
}
