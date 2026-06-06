import Testing
@testable import ObfuskoderKit

private func roundTrips(_ input: String, k: Int, mask: Int, reversed: Bool) throws {
    let p = EncodeParameters(k: k, mask: mask, reversed: reversed, id: "OBFUSKODER_rt0001")
    let art = Encoder.buildArtifact(input: input, parameters: p,
                                    fallbackMessage: "Enable JavaScript to view email")
    try SelfCheck.verifyRoundTrip(art)   // throws on mismatch
}

@Test func roundTripsSimpleAnchor() throws {
    try roundTrips(#"<a href="mailto:user@example.com">Email me</a>"#, k: 9, mask: 0, reversed: false)
}

@Test func roundTripsWithMaskAndReverse() throws {
    try roundTrips(#"<a href="mailto:user@example.com" title="hi">Email me</a>"#, k: 200, mask: 137, reversed: true)
}

@Test func roundTripsUnicodeAndMultiTag() throws {
    try roundTrips("<p>Hi 😀 <strong>bold</strong> &amp; more</p>", k: 17, mask: 42, reversed: true)
}

@Test func detectsBrokenDecoder() {
    let art = EncodedArtifact(
        html: #"<span id="OBFUSKODER_bad001">f</span><script id="OBFUSKODER_bad001_s">(function(){var el=document.getElementById("OBFUSKODER_bad001");if(el){el.outerHTML="WRONG";}})();</script>"#,
        spanID: "OBFUSKODER_bad001", scriptID: "OBFUSKODER_bad001_s",
        decoderJS: #"(function(){var el=document.getElementById("OBFUSKODER_bad001");if(el){el.outerHTML="WRONG";}})();"#,
        input: "RIGHT")
    #expect(throws: (any Error).self) { try SelfCheck.verifyRoundTrip(art) }
}
