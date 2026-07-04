import Testing
@testable import ObfuskoderKit

@Test(arguments: [
    // (proposed text, cursor, expected text, expected cursor) — UTF-16 offsets
    ("hello", 3, "hello", 3),          // no @: untouched
    ("abc@def", 4, "abcdef", 3),       // typed @ mid-string: cursor stays at edit point
    ("@abc", 1, "abc", 0),             // typed @ at start
    ("a@@b", 3, "ab", 1),              // pasted @@ after "a", cursor after paste
    ("a@@b", 4, "ab", 2),              // same text, cursor at end
    ("ab@cd", 1, "abcd", 1),           // @ after cursor doesn't move it
    ("😀@x", 3, "😀x", 2),             // emoji is 2 UTF-16 units; @ removal shifts by 1
    ("@@@", 3, "", 0),                 // all @: everything stripped
    ("", 0, "", 0),                    // empty stays empty
])
func stripsAtSignsAndAdjustsCursor(proposed: String, cursor: Int, expectedText: String, expectedCursor: Int) {
    let result = FallbackSanitizer.strippingAtSigns(from: proposed, cursor: cursor)
    #expect(result.text == expectedText)
    #expect(result.cursor == expectedCursor)
}

@Test func clampsOutOfRangeCursor() {
    // Defensive: a cursor beyond the text (shouldn't happen, but NSRange math
    // upstream can be off-by-one) must not produce a negative or overflowing result.
    let past = FallbackSanitizer.strippingAtSigns(from: "a@", cursor: 99)
    #expect(past.text == "a")
    #expect(past.cursor == 1)
    let negative = FallbackSanitizer.strippingAtSigns(from: "@a", cursor: -1)
    #expect(negative.text == "a")
    #expect(negative.cursor == 0)
}
