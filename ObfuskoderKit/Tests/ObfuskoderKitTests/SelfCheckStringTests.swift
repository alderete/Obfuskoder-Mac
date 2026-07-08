import Testing
@testable import ObfuskoderKit

@Test func passesCleanArtifact() throws {
    let p = EncodeParameters(k: 7, mask: 0, reversed: false, id: "OBFUSKODER_clean1")
    let art = Encoder.buildArtifact(input: #"<a href="mailto:user@example.com">hi</a>"#,
                                    parameters: p, fallbackMessage: "Enable JavaScript to view email")
    try SelfCheck.verifyStringProperties(art, email: "user@example.com")  // no throw
}

@Test func throwsOnAtSign() {
    let p = EncodeParameters(k: 7, mask: 0, reversed: false, id: "OBFUSKODER_atsign")
    let art = Encoder.buildArtifact(input: "hello", parameters: p, fallbackMessage: "ping@pong")
    #expect(throws: SelfCheckError.atSignPresent) {
        try SelfCheck.verifyStringProperties(art, email: nil)
    }
}

// ENC-2 (SPEC §7.1): incidental matches against the fixed decoder skeleton,
// the random element ids, or the encoded numbers are not leaks — plaintext
// can only surface in the fallback text.
@Test func boilerplateSubstringInputsAreNotLeaks() throws {
    for input in ["a", "1", "var", "if", "document", "OBFUSKODER_",
                  "Enable JavaScript to view email"] {
        let p = EncodeParameters(k: 7, mask: 0, reversed: false, id: "OBFUSKODER_clean2")
        let art = Encoder.buildArtifact(input: input, parameters: p,
                                        fallbackMessage: "JS required")
        try SelfCheck.verifyStringProperties(art, email: nil)  // no throw
    }
}

// A fragment of an unrelated fallback word is incidental, not a leak:
// "a" occurs inside "JavaScript" but never as standalone text.
@Test func inputAsWordFragmentOfFallbackIsNotALeak() throws {
    for input in ["a", "vie", "Script"] {
        let p = EncodeParameters(k: 7, mask: 0, reversed: false, id: "OBFUSKODER_clean3")
        let art = Encoder.buildArtifact(input: input, parameters: p,
                                        fallbackMessage: "Enable JavaScript to view email")
        try SelfCheck.verifyStringProperties(art, email: nil)  // no throw
    }
}

@Test func fallbackContainingInputIsALeak() {
    let p = EncodeParameters(k: 7, mask: 0, reversed: false, id: "OBFUSKODER_leak01")
    let art = Encoder.buildArtifact(input: "hello", parameters: p,
                                    fallbackMessage: "well hello there")
    #expect(throws: SelfCheckError.fallbackContainsPlaintext) {
        try SelfCheck.verifyStringProperties(art, email: nil)
    }
}

// Entity-escaping the fallback (item 1) must not manufacture leak matches:
// "&" renders as "&amp;" in the published bytes, but an input of "amp" is
// still only a fragment of the user's own ampersand, not standalone text.
@Test func entityEscapedFallbackDoesNotFalselyFlagInput() throws {
    let p = EncodeParameters(k: 7, mask: 0, reversed: false, id: "OBFUSKODER_leak02")
    let art = Encoder.buildArtifact(input: "amp", parameters: p,
                                    fallbackMessage: "this & that")
    try SelfCheck.verifyStringProperties(art, email: nil)  // no throw
}

@Test func fallbackContainingEmailIsALeak() {
    let p = EncodeParameters(k: 7, mask: 0, reversed: false, id: "OBFUSKODER_leak03")
    // No '@' so the atSign check can't fire first; the email check must.
    let art = Encoder.buildArtifact(input: "<b>hi there</b>", parameters: p,
                                    fallbackMessage: "reach sue.example somehow")
    #expect(throws: SelfCheckError.fallbackContainsPlaintext) {
        try SelfCheck.verifyStringProperties(art, email: "sue.example")
    }
}

// Defense-in-depth: the raw email must not appear anywhere in the snippet,
// however it got there (an encoder bug would be caught here, not retried away).
@Test func throwsWhenEmailAppearsOutsideFallback() {
    let art = EncodedArtifact(html: "<span>contact user@example.com</span>",
                              spanID: "x", scriptID: "x_s", decoderJS: "",
                              input: "unrelated", fallback: "")
    #expect(throws: SelfCheckError.plaintextLeak) {
        try SelfCheck.verifyStringProperties(art, email: "user@example.com")
    }
}
