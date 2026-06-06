import Testing
@testable import ObfuskoderKit

@Test func appConfigDefaults() {
    #expect(AppConfig.defaultDebounceSeconds == 0.4)
    #expect(AppConfig.defaultFallbackMessage == "Enable JavaScript to view email")
    #expect(AppConfig.accentHex == "5E7C50")
    #expect(AppConfig.maxSelfCheckAttempts == 8)
}
