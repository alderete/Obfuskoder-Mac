import Testing
@testable import ObfuskoderKit

@Test func acceptsWellFormedAddresses() {
    #expect(EmailValidator.isValid("user@example.com"))
    #expect(EmailValidator.isValid("a.b+c@sub.example.co.uk"))
    #expect(EmailValidator.isValid("  trimmed@example.com  "))   // trims first
}

@Test func rejectsMalformedAddresses() {
    #expect(!EmailValidator.isValid(""))
    #expect(!EmailValidator.isValid("no-at-sign.com"))
    #expect(!EmailValidator.isValid("two@@example.com"))
    #expect(!EmailValidator.isValid("missing@domain"))
    #expect(!EmailValidator.isValid("space in@example.com"))
}
