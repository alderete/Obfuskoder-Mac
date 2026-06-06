import Testing
@testable import ObfuskoderKit

@Test func encodeProducesValidSnippet() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "Enable JavaScript to view email")
    let input = #"<a href="mailto:user@example.com">Email me</a>"#
    let snippet = try engine.encode(input, email: "user@example.com")
    #expect(snippet.decodedSource == input)
    #expect(!snippet.html.contains("@"))
    #expect(!snippet.html.contains("user@example.com"))
    #expect(snippet.html.contains("<script"))
}

@Test func encodeIsNonDeterministic() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "Enable JavaScript to view email")
    let input = #"<a href="mailto:user@example.com">Email me</a>"#
    let a = try engine.encode(input, email: "user@example.com")
    let b = try engine.encode(input, email: "user@example.com")
    #expect(a.html != b.html)   // ENC-6 (random seed per encode)
}

@Test func encodeRoundTripsFiftyRandomInputs() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "Enable JavaScript to view email")
    for i in 0..<50 {
        let input = #"<a href="mailto:user\#(i)@example.com" title="t\#(i)">Email \#(i) 😀</a>"#
        let snippet = try engine.encode(input, email: "user\(i)@example.com")
        let art = EncodedArtifact(html: snippet.html, spanID: "", scriptID: "",
                                  decoderJS: extractDecoder(from: snippet.html), input: input)
        try SelfCheck.verifyRoundTrip(art)
    }
}

private func extractDecoder(from html: String) -> String {
    guard let open = html.range(of: "<script"),
          let gt = html.range(of: ">", range: open.upperBound..<html.endIndex),
          let close = html.range(of: "</script>", range: gt.upperBound..<html.endIndex)
    else { return "" }
    return String(html[gt.upperBound..<close.lowerBound])
}
