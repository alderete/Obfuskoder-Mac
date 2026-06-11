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

private func runCore(_ input: CLIInput, stdinData: Data? = nil, tty: Bool = false) throws -> String {
    try ObfuskodeCLICore.run(input, readStdin: { stdinData }, stdinIsTTY: { tty })
}

private func basicInput(email: String? = "sue@example.com",
                        linkText: String? = "Email Sue",
                        linkTitle: String? = nil,
                        subject: String? = nil,
                        html: String? = nil,
                        fallback: String = AppConfig.defaultFallbackMessage) -> CLIInput {
    CLIInput(email: email, linkText: linkText, linkTitle: linkTitle,
             subject: subject, html: html, fallback: fallback)
}

@Test func basicModeProducesVerifiedSnippet() throws {
    let snippet = try runCore(basicInput())
    #expect(!snippet.contains("@"))                    // ENC-3
    #expect(!snippet.contains("sue@example.com"))      // ENC-2
    #expect(snippet.contains("<script"))
    #expect(snippet.contains("Enable JavaScript to view email"))  // default fallback (CLI-19)
}

@Test func basicModeAcceptsAllFields() throws {
    let snippet = try runCore(basicInput(linkTitle: "Send Sue a message", subject: "Hello"))
    #expect(!snippet.contains("@"))
}

@Test func twoEncodesDiffer() throws {                 // ENC-6 / CLI-18
    let input = basicInput()
    #expect(try runCore(input) != (try runCore(input)))
}

@Test func invalidEmailIsDataError() {                 // CLI-10
    #expect(throws: CLIFailure.data("'not-an-email' is not a valid email address")) {
        _ = try runCore(basicInput(email: "not-an-email"))
    }
}

@Test func blankLinkTextIsDataError() {                // CLI-11
    #expect(throws: CLIFailure.data("the link text must not be empty")) {
        _ = try runCore(basicInput(linkText: "   "))
    }
}

@Test func fallbackWithAtSignIsDataError() {           // CLI-12
    #expect(throws: CLIFailure.data("the fallback message must not contain the '@' character")) {
        _ = try runCore(basicInput(fallback: "mail me @ home"))
    }
}

@Test func emptyFallbackIsAllowed() throws {           // CLI-12
    let snippet = try runCore(basicInput(fallback: ""))
    #expect(snippet.contains("<script"))
}

@Test func customFallbackAppears() throws {
    let snippet = try runCore(basicInput(fallback: "JavaScript required"))
    #expect(snippet.contains("JavaScript required"))
}

@Test func htmlModeEncodesVerbatimInput() throws {     // §5.3
    let snippet = try runCore(basicInput(email: nil, linkText: nil, html: "  <b>hi</b>\n"))
    #expect(snippet.contains("<script"))
    #expect(!snippet.contains("<b>hi</b>"))            // ENC-2: input absent from static text
}

@Test func emptyHTMLIsDataError() {                    // CLI-13
    #expect(throws: CLIFailure.data("no HTML to obfuskode (input is empty)")) {
        _ = try runCore(basicInput(email: nil, linkText: nil, html: "   \n"))
    }
}

@Test func fallbackContainingInputIsSoftwareError() {  // §5.8
    do {
        _ = try runCore(basicInput(email: nil, linkText: nil,
                                   html: "hello", fallback: "well hello there"))
        Issue.record("expected a software failure")
    } catch let failure as CLIFailure {
        guard case .software(let message) = failure else {
            Issue.record("expected .software, got \(failure)"); return
        }
        #expect(message.contains("fallback message contains the input text"))
    } catch {
        Issue.record("unexpected error type: \(error)")
    }
}
