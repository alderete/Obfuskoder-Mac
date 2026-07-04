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

@Test func returnsNilWhenEmailInvalid() {
    #expect(BasicFields(email: "bad", linkText: "x").canonicalHTML() == nil)
    #expect(BasicFields(email: "", linkText: "").canonicalHTML() == nil)
}

// Empty (or whitespace-only) link text falls back to the email address —
// "half the time, the link text is just the email address repeated".
@Test func emptyLinkTextFallsBackToEmail() {
    let f = BasicFields(email: "user@example.com", linkText: "")
    #expect(f.canonicalHTML() == #"<a href="mailto:user@example.com">user@example.com</a>"#)
}

@Test func whitespaceLinkTextFallsBackToEmail() {
    let f = BasicFields(email: "user@example.com", linkText: "   ")
    #expect(f.canonicalHTML() == #"<a href="mailto:user@example.com">user@example.com</a>"#)
}

@Test func fallbackKeepsTitleAndSubject() {
    let f = BasicFields(email: "user@example.com", linkText: "", linkTitle: "Contact", subject: "Hi")
    #expect(f.canonicalHTML() ==
        #"<a href="mailto:user@example.com?subject=Hi" title="Contact">user@example.com</a>"#)
}

@Test func escapesTextAndTitleAndEncodesSubject() {
    let f = BasicFields(email: "user@example.com", linkText: "A & B <x>",
                        linkTitle: #"q"o"#, subject: "a & b")
    #expect(f.canonicalHTML() ==
        #"<a href="mailto:user@example.com?subject=a%20%26%20b" title="q&quot;o">A &amp; B &lt;x&gt;</a>"#)
}
