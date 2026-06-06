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

@Test func throwsOnPlaintextLeak() {
    let art = EncodedArtifact(html: "<span>leak: secret-input</span>",
                              spanID: "x", scriptID: "x_s", decoderJS: "", input: "secret-input")
    #expect(throws: SelfCheckError.plaintextLeak) {
        try SelfCheck.verifyStringProperties(art, email: nil)
    }
}

@Test func throwsWhenEmailAppears() {
    let art = EncodedArtifact(html: "<span>contact user@example.com</span>",
                              spanID: "x", scriptID: "x_s", decoderJS: "", input: "unrelated")
    #expect(throws: SelfCheckError.plaintextLeak) {
        try SelfCheck.verifyStringProperties(art, email: "user@example.com")
    }
}
