import Testing
import ObfuskoderKit

@Test func explicitCommandsWin() {
    #expect(classifyEdit(before: "ab", beforeSelection: EditSelection(location: 2),
                         after: "a", afterSelection: EditSelection(location: 1),
                         command: .deleteBackward) == .deleteBackward)
    #expect(classifyEdit(before: "ab", beforeSelection: EditSelection(location: 0),
                         after: "b", afterSelection: EditSelection(location: 0),
                         command: .deleteForward) == .deleteForward)
    #expect(classifyEdit(before: "abc", beforeSelection: EditSelection(location: 0, length: 3),
                         after: "", afterSelection: EditSelection(location: 0),
                         command: .cut) == .cut)
    #expect(classifyEdit(before: "", beforeSelection: EditSelection(location: 0),
                         after: "a@b.com", afterSelection: EditSelection(location: 7),
                         command: .completeLinkText) == .completeLinkText)
}

@Test func inferInsertVsPaste() {
    // A single new char at the caret ⇒ typing.
    #expect(classifyEdit(before: "a", beforeSelection: EditSelection(location: 1),
                         after: "ab", afterSelection: EditSelection(location: 2),
                         command: nil) == .insert)
    // Several chars arriving in one event ⇒ paste/drop, not typing.
    #expect(classifyEdit(before: "a", beforeSelection: EditSelection(location: 1),
                         after: "aXYZ", afterSelection: EditSelection(location: 4),
                         command: nil) == .paste)
}

@Test func inferReplaceWhenSelectionExisted() {
    #expect(classifyEdit(before: "abcd", beforeSelection: EditSelection(location: 1, length: 2),
                         after: "aXd", afterSelection: EditSelection(location: 2),
                         command: nil) == .replace)
}

@Test func inferDeleteDirectionFromCaret() {
    #expect(classifyEdit(before: "ab", beforeSelection: EditSelection(location: 2),
                         after: "a", afterSelection: EditSelection(location: 1),
                         command: nil) == .deleteBackward)
    #expect(classifyEdit(before: "ab", beforeSelection: EditSelection(location: 0),
                         after: "b", afterSelection: EditSelection(location: 0),
                         command: nil) == .deleteForward)
}
