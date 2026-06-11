import Testing
import Foundation
import ObfuskoderKit
import ObfuskodeCLI

@Test func cliInputStoresFields() {
    let input = CLIInput(email: "sue@example.com", linkText: "Email Sue",
                         fallback: AppConfig.defaultFallbackMessage)
    #expect(input.email == "sue@example.com")
    #expect(input.html == nil)
    #expect(input.fallback == "Enable JavaScript to view email")
}
