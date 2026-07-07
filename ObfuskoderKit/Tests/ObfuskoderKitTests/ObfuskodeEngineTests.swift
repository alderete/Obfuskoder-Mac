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

@Test func encodeEscapesFallbackMarkup() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "<script>alert(1)</script>Turn on JS, please")
    let snippet = try engine.encode(#"<a href="mailto:zed@example.com">Zebra Quill</a>"#)
    #expect(!snippet.html.contains("<script>alert(1)</script>"))
    #expect(snippet.html.contains("&lt;script&gt;alert(1)&lt;/script&gt;Turn on JS, please"))
}

@Test func encodeRoundTripsFiftyRandomInputs() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "Enable JavaScript to view email")
    for i in 0..<50 {
        let input = #"<a href="mailto:user\#(i)@example.com" title="t\#(i)">Email \#(i) 😀</a>"#
        let snippet = try engine.encode(input, email: "user\(i)@example.com")
        let spanID = extractSpanID(from: snippet.html)
        let art = EncodedArtifact(html: snippet.html, spanID: spanID, scriptID: spanID + "_s",
                                  decoderJS: extractDecoder(from: snippet.html), input: input,
                                  fallback: "Enable JavaScript to view email")
        try SelfCheck.verifyRoundTrip(art)
    }
}

// ENC-2 must not reject inputs that merely coincide with the snippet's fixed
// skeleton or with common words (SPEC §7.1: incidental substring matches in
// unrelated context are not leaks).
@Test func encodeAcceptsShortAndBoilerplateLikeInputs() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "JS required")
    for input in ["a", "1", "hi", "var", "document", "Enable JavaScript to view email"] {
        let snippet = try engine.encode(input)
        #expect(snippet.decodedSource == input)
        #expect(snippet.html.contains("<script"))
    }
}

// A fallback that contains the input is deterministic: the engine must fail
// fast with the cause, not burn retries and report a generic repeated failure.
@Test func fallbackContainingInputFailsFastWithCause() {
    let engine = ObfuskodeEngine(fallbackMessage: "well hello there")
    #expect(throws: ObfuskodeError.selfCheckFailed(.fallbackContainsPlaintext)) {
        _ = try engine.encode("hello")
    }
}

@Test func zeroMaxAttemptsStillAttemptsOnce() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "JS required", maxAttempts: 0)
    let snippet = try engine.encode("<b>hi there</b>")
    #expect(snippet.decodedSource == "<b>hi there</b>")
}

private func extractDecoder(from html: String) -> String {
    guard let open = html.range(of: "<script"),
          let gt = html.range(of: ">", range: open.upperBound..<html.endIndex),
          let close = html.range(of: "</script>", range: gt.upperBound..<html.endIndex)
    else { return "" }
    return String(html[gt.upperBound..<close.lowerBound])
}

private func extractSpanID(from html: String) -> String {
    let marker = #"<span id=""#
    guard let open = html.range(of: marker),
          let close = html.range(of: "\"", range: open.upperBound..<html.endIndex)
    else { return "" }
    return String(html[open.upperBound..<close.lowerBound])
}
