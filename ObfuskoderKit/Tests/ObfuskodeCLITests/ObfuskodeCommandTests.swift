import Testing
import Foundation
import ArgumentParser
import ObfuskoderKit
import ObfuskodeCLI

private func expectExit64(_ arguments: [String]) {
    do {
        _ = try ObfuskodeCommand.parse(arguments)
        Issue.record("expected a usage error for \(arguments)")
    } catch {
        #expect(ObfuskodeCommand.exitCode(for: error) == .validationFailure)  // 64
    }
}

@Test func parsesShortFlags() throws {
    let command = try ObfuskodeCommand.parse(["-e", "sue@example.com", "-t", "Email Sue"])
    #expect(command.email == "sue@example.com")
    #expect(command.linkText == "Email Sue")
}

@Test func parsesAllLongOptions() throws {
    let command = try ObfuskodeCommand.parse([
        "--email", "sue@example.com", "--link-text", "Email Sue",
        "--link-title", "Send Sue a message", "--subject", "Hello",
        "--fallback", "JS required"
    ])
    #expect(command.linkTitle == "Send Sue a message")
    #expect(command.subject == "Hello")
    #expect(command.fallback == "JS required")
}

@Test func fallbackDefaultsToAppConfig() throws {
    let command = try ObfuskodeCommand.parse(["--html", "<b>hi</b>"])
    #expect(command.fallback == AppConfig.defaultFallbackMessage)
}

@Test func emailAndHTMLConflict() {                    // CLI-4
    expectExit64(["-e", "a@b.co", "-t", "Hi", "--html", "<p>x</p>"])
}

@Test func companionsRequireEmail() {                  // CLI-5
    expectExit64(["--link-text", "x"])
    expectExit64(["--link-text", "x", "--html", "<p>x</p>"])
    expectExit64(["--link-title", "x", "--html", "<p>x</p>"])
    expectExit64(["--subject", "x", "--html", "<p>x</p>"])
}

// CLI-6 (revised): --email without --link-text is valid; the link text
// falls back to the email address.
@Test func emailAloneParses() throws {
    let command = try ObfuskodeCommand.parse(["-e", "a@b.co"])
    #expect(command.email == "a@b.co")
    #expect(command.linkText == nil)
}

@Test func helpIncludesExamples() {                    // §5.10
    let help = ObfuskodeCommand.helpMessage()
    #expect(help.contains("pbpaste | obfuskode | pbcopy"))
    #expect(help.contains("randomized"))               // CLI-18 documented
}

private final class IOCapture {
    var out = ""
    var err = ""
    func io(stdin: Data? = nil, tty: Bool = false) -> CLIIO {
        CLIIO(readStdin: { stdin },
              stdinIsTTY: { tty },
              writeOut: { self.out += $0 },
              writeErr: { self.err += $0 })
    }
}

@Test func executeWritesSnippetPlusOneNewline() throws {   // CLI-15 / CLI-16
    let capture = IOCapture()
    try ObfuskodeCommand.execute(
        input: CLIInput(email: "sue@example.com", linkText: "Email Sue",
                        fallback: AppConfig.defaultFallbackMessage),
        io: capture.io())
    #expect(capture.out.hasSuffix("\n"))
    #expect(!capture.out.hasSuffix("\n\n"))
    #expect(capture.out.contains("<script"))
    #expect(!capture.out.contains("@"))
    #expect(capture.err.isEmpty)
}

@Test func executeDataErrorWritesStderrAndExits65() {      // §5.7
    let capture = IOCapture()
    do {
        try ObfuskodeCommand.execute(
            input: CLIInput(email: "nope", linkText: "Hi",
                            fallback: AppConfig.defaultFallbackMessage),
            io: capture.io())
        Issue.record("expected ExitCode(65)")
    } catch let code as ExitCode {
        #expect(code == ExitCode(65))
    } catch {
        Issue.record("unexpected error type: \(error)")
    }
    #expect(capture.err == "obfuskode: 'nope' is not a valid email address\n")
    #expect(capture.out.isEmpty)
}

@Test func executeSoftwareErrorExits70() {                 // §5.8
    let capture = IOCapture()
    do {
        try ObfuskodeCommand.execute(
            input: CLIInput(html: "hello", fallback: "well hello there"),
            io: capture.io())
        Issue.record("expected ExitCode(70)")
    } catch let code as ExitCode {
        #expect(code == ExitCode(70))
    } catch {
        Issue.record("unexpected error type: \(error)")
    }
    #expect(capture.err.hasPrefix("obfuskode: the encoded snippet failed its self-check repeatedly."))
    #expect(capture.out.isEmpty)
}

@Test func executeTTYNoInputThrowsValidationError() {      // CLI-7 → 64 with usage
    let capture = IOCapture()
    do {
        try ObfuskodeCommand.execute(
            input: CLIInput(fallback: AppConfig.defaultFallbackMessage),
            io: capture.io(tty: true))
        Issue.record("expected ValidationError")
    } catch {
        #expect(ObfuskodeCommand.exitCode(for: error) == .validationFailure)
    }
}

@Test func executeStdinPipeline() throws {
    let capture = IOCapture()
    try ObfuskodeCommand.execute(
        input: CLIInput(fallback: AppConfig.defaultFallbackMessage),
        io: capture.io(stdin: Data("<b>hi</b>".utf8)))
    #expect(capture.out.contains("<script"))
}
