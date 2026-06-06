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
