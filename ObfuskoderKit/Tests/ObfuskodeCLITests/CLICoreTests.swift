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

// CLI-11 (revised): omitted or blank --link-text falls back to the email
// address; it is not an error.
@Test func omittedLinkTextFallsBackToEmail() throws {
    let snippet = try runCore(basicInput(linkText: nil))
    #expect(snippet.contains("@") == false)
    #expect(snippet.isEmpty == false)
}

@Test func blankLinkTextFallsBackToEmail() throws {
    let snippet = try runCore(basicInput(linkText: "   "))
    #expect(snippet.contains("@") == false)
    #expect(snippet.isEmpty == false)
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

@Test func fallbackMarkupIsEscapedInOutput() throws {
    let snippet = try runCore(basicInput(email: nil, linkText: nil,
                                         html: "<b>hello world</b>",
                                         fallback: "</span><script>alert(1)</script><span>"))
    #expect(!snippet.contains("<script>alert(1)</script>"))
    #expect(snippet.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
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

// §5.8 (revised): a fallback that would leak the input is the user's data to
// fix — a data error (65), not a "report this bug" software error (70).
@Test func fallbackContainingInputIsDataError() {
    #expect(throws: CLIFailure.data("the fallback message contains the input text (the snippet would leak it)")) {
        _ = try runCore(basicInput(email: nil, linkText: nil,
                                   html: "hello", fallback: "well hello there"))
    }
}

// ENC-2 false-positive regression: inputs that coincide with the decoder
// skeleton's own keywords must encode fine.
@Test func boilerplateLikeInputsEncode() throws {
    for html in ["a", "var", "document"] {
        let snippet = try runCore(basicInput(email: nil, linkText: nil, html: html))
        #expect(snippet.contains("<script"))
    }
}

@Test func stdinModeEncodesPipedHTML() throws {
    let input = basicInput(email: nil, linkText: nil)
    let snippet = try runCore(input, stdinData: Data("<b>hi</b>".utf8))
    #expect(snippet.contains("<script"))
}

@Test func emptyStdinIsDataError() {
    #expect(throws: CLIFailure.data("no HTML to obfuskode (input is empty)")) {
        _ = try runCore(basicInput(email: nil, linkText: nil), stdinData: Data())
    }
}

@Test func nilStdinIsDataError() {
    #expect(throws: CLIFailure.data("no HTML to obfuskode (input is empty)")) {
        _ = try runCore(basicInput(email: nil, linkText: nil), stdinData: nil)
    }
}

private struct StdinReadFailure: Error {}

// A genuine stdin read failure must be reported as such, not misreported as
// "input is empty" (which sends the user looking in the wrong place).
@Test func stdinReadErrorIsReportedDistinctly() {
    do {
        _ = try ObfuskodeCLICore.run(basicInput(email: nil, linkText: nil),
                                     readStdin: { throw StdinReadFailure() },
                                     stdinIsTTY: { false })
        Issue.record("expected a data failure")
    } catch let failure as CLIFailure {
        guard case .data(let message) = failure else {
            Issue.record("expected .data, got \(failure)"); return
        }
        #expect(message.hasPrefix("could not read standard input"))
        #expect(!message.contains("empty"))
    } catch {
        Issue.record("unexpected error type: \(error)")
    }
}

@Test func invalidUTF8StdinIsDataError() {             // CLI-14
    #expect(throws: CLIFailure.data("standard input is not valid UTF-8")) {
        _ = try runCore(basicInput(email: nil, linkText: nil),
                        stdinData: Data([0xFF, 0xFE, 0xFD]))
    }
}

@Test func ttyWithNoInputIsUsageError() {              // CLI-7: never hang on a TTY
    #expect(throws: CLIFailure.usage("missing input: pass --email or --html, or pipe HTML to standard input")) {
        _ = try runCore(basicInput(email: nil, linkText: nil), tty: true)
    }
}

@Test func flagsTakePrecedenceOverStdin() throws {     // CLI-8: stdin ignored when a flag is given
    let snippet = try runCore(basicInput(), stdinData: Data("<b>ignored</b>".utf8))
    #expect(!snippet.contains("ignored"))
}
