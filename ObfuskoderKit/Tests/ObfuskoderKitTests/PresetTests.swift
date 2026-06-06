import Testing
import Foundation
@testable import ObfuskoderKit

@Test func presetPayloadCodableRoundTrip() throws {
    let payloads: [PresetPayload] = [
        .basic(BasicFields(email: "user@example.com", linkText: "Email me")),
        .advanced("<b>hi</b>")
    ]
    for payload in payloads {
        let preset = Preset(id: UUID(), name: "n", payload: payload)
        let data = try JSONEncoder().encode(preset)
        let back = try JSONDecoder().decode(Preset.self, from: data)
        #expect(back == preset)
    }
}

@Test func applyBasicPresetSwitchesModeAndFills() {
    var s = FormState()
    s.mode = .advanced
    s.apply(Preset(id: UUID(), name: "p",
                   payload: .basic(BasicFields(email: "user@example.com", linkText: "Email me"))))
    #expect(s.mode == .basic)
    #expect(s.basic.email == "user@example.com")
}

@Test func applyAdvancedPresetSwitchesModeAndFills() {
    var s = FormState()
    s.apply(Preset(id: UUID(), name: "p", payload: .advanced("<i>x</i>")))
    #expect(s.mode == .advanced)
    #expect(s.advanced == "<i>x</i>")
}
