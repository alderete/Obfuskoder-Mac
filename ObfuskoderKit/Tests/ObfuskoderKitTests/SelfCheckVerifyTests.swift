import Testing
@testable import ObfuskoderKit

@Test func verifyRunsAllThreeChecks() throws {
    let p = EncodeParameters(k: 11, mask: 99, reversed: true, id: "OBFUSKODER_all001")
    let art = Encoder.buildArtifact(input: #"<a href="mailto:user@example.com">Email me</a>"#,
                                    parameters: p, fallbackMessage: "Enable JavaScript to view email")
    try SelfCheck.verify(art, email: "user@example.com")  // no throw
}
