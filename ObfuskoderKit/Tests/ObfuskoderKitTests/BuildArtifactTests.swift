import Testing
@testable import ObfuskoderKit

@Test func buildsSnippetStructureWithoutAtSign() {
    let p = EncodeParameters(k: 5, mask: 0, reversed: false, id: "OBFUSKODER_test01")
    let art = Encoder.buildArtifact(input: #"<a href="mailto:user@example.com">Email me</a>"#,
                                    parameters: p,
                                    fallbackMessage: "Enable JavaScript to view email")
    #expect(art.spanID == "OBFUSKODER_test01")
    #expect(art.scriptID == "OBFUSKODER_test01_s")
    #expect(art.html.contains(#"<span id="OBFUSKODER_test01">Enable JavaScript to view email</span>"#))
    #expect(art.html.contains(#"<script id="OBFUSKODER_test01_s">"#))
    #expect(art.html.hasSuffix("</script>"))
    #expect(!art.html.contains("@"))                 // ENC-3 by construction
    #expect(!art.html.contains("user@example.com"))  // ENC-2 by construction
    #expect(art.input == #"<a href="mailto:user@example.com">Email me</a>"#)
}

// The fallback is display text for non-JS visitors, not markup: anything the
// user types must be HTML-escaped so it can neither close the fallback span
// nor inject live elements into the published page.
@Test func escapesMarkupInFallbackMessage() {
    let p = EncodeParameters(k: 5, mask: 0, reversed: false, id: "OBFUSKODER_test02")
    let art = Encoder.buildArtifact(input: "<b>hello world</b>",
                                    parameters: p,
                                    fallbackMessage: #"</span><script>alert(1)</script> & <b>go</b>"#)
    #expect(art.html.contains(
        #"<span id="OBFUSKODER_test02">&lt;/span&gt;&lt;script&gt;alert(1)&lt;/script&gt; &amp; &lt;b&gt;go&lt;/b&gt;</span>"#))
    #expect(!art.html.contains("<script>alert(1)</script>"))
    // Snippet structure survives: exactly one span and one script element.
    #expect(art.html.components(separatedBy: "</span>").count == 2)
    #expect(art.html.components(separatedBy: "</script>").count == 2)
}
