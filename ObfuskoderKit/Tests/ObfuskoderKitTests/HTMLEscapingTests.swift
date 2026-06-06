import Testing
@testable import ObfuskoderKit

@Test func escapesTextContent() {
    #expect(htmlEscapeText("a & b < c > d") == "a &amp; b &lt; c &gt; d")
    #expect(htmlEscapeText("plain") == "plain")
}

@Test func escapesAttributeContent() {
    #expect(htmlEscapeAttribute(#"say "hi" & <go>"#) == "say &quot;hi&quot; &amp; &lt;go&gt;")
}

@Test func percentEncodesSubjectLikeEncodeURIComponent() {
    #expect(percentEncodeComponent("Hello World & more") == "Hello%20World%20%26%20more")
    #expect(percentEncodeComponent("a-b_c.d~e") == "a-b_c.d~e")   // unreserved untouched
}
