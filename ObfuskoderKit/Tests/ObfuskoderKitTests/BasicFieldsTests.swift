import Testing
@testable import ObfuskoderKit

@Test func buildsFullAnchor() {
    let f = BasicFields(email: "user@example.com", linkText: "Email me",
                        linkTitle: "Contact", subject: "Hello there")
    #expect(f.canonicalHTML() ==
        #"<a href="mailto:user@example.com?subject=Hello%20there" title="Contact">Email me</a>"#)
}

@Test func omitsSubjectAndTitleWhenEmpty() {
    let f = BasicFields(email: "user@example.com", linkText: "Email me")
    #expect(f.canonicalHTML() == #"<a href="mailto:user@example.com">Email me</a>"#)
}

@Test func returnsNilWhenInvalid() {
    #expect(BasicFields(email: "bad", linkText: "x").canonicalHTML() == nil)        // bad email
    #expect(BasicFields(email: "user@example.com", linkText: "   ").canonicalHTML() == nil) // empty text
}

@Test func escapesTextAndTitleAndEncodesSubject() {
    let f = BasicFields(email: "user@example.com", linkText: "A & B <x>",
                        linkTitle: #"q"o"#, subject: "a & b")
    #expect(f.canonicalHTML() ==
        #"<a href="mailto:user@example.com?subject=a%20%26%20b" title="q&quot;o">A &amp; B &lt;x&gt;</a>"#)
}
