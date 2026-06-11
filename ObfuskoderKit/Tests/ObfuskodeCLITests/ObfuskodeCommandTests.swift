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
    expectExit64(["--link-title", "x", "--html", "<p>x</p>"])
    expectExit64(["--subject", "x", "--html", "<p>x</p>"])
}

@Test func emailRequiresLinkText() {                   // CLI-6
    expectExit64(["-e", "a@b.co"])
}

@Test func helpIncludesExamples() {                    // §5.10
    let help = ObfuskodeCommand.helpMessage()
    #expect(help.contains("pbpaste | obfuskode | pbcopy"))
    #expect(help.contains("randomized"))               // CLI-18 documented
}
