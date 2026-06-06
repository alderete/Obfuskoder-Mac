import Testing
@testable import ObfuskoderKit

@Test func basicModeInputAndEmail() {
    var s = FormState()
    s.mode = .basic
    s.basic = BasicFields(email: "user@example.com", linkText: "Email me")
    #expect(s.canonicalInput == #"<a href="mailto:user@example.com">Email me</a>"#)
    #expect(s.emailForSelfCheck == "user@example.com")
}

@Test func basicModeInvalidYieldsNilInput() {
    var s = FormState()
    s.mode = .basic
    s.basic = BasicFields(email: "bad", linkText: "x")
    #expect(s.canonicalInput == nil)
    #expect(s.emailForSelfCheck == nil)
}

@Test func advancedModeUsesTrimmedTextAndNilEmail() {
    var s = FormState()
    s.mode = .advanced
    s.advanced = "  <b>hi</b>  "
    #expect(s.canonicalInput == "<b>hi</b>")
    #expect(s.emailForSelfCheck == nil)
}

@Test func activeIsEmptyTracksActiveModeOnly() {
    var s = FormState()
    s.mode = .basic
    #expect(s.activeIsEmpty)
    s.basic.email = "x"
    #expect(!s.activeIsEmpty)
    s.mode = .advanced
    #expect(s.activeIsEmpty)
}

@Test func clearActiveClearsOnlyActiveMode() {
    var s = FormState()
    s.mode = .basic
    s.basic = BasicFields(email: "user@example.com", linkText: "Email me")
    s.advanced = "keep me"
    s.clearActive()
    #expect(s.basic == BasicFields())
    #expect(s.advanced == "keep me")
}

@Test func payloadReflectsActiveMode() {
    var s = FormState()
    s.mode = .advanced
    s.advanced = "<i>x</i>"
    #expect(s.payload() == .advanced("<i>x</i>"))
}
