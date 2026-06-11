import Foundation
import ArgumentParser
import ObfuskoderKit

/// The `obfuskode` command (SPEC-CLI §5). Parsing and flag rules live here;
/// the pipeline lives in ObfuskodeCLICore; I/O goes through CLIIO.
public struct ObfuskodeCommand: ParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "obfuskode",
            abstract: "Obfuscate an email address or HTML snippet for safe publication on a web page.",
            discussion: """
            EXAMPLES:
              obfuskode --email sue@example.com --link-text "Email Sue"
              obfuskode -e sue@example.com -t "Email Sue" --link-title "Send Sue a message" --subject "Hello"
              obfuskode --html '<a href="mailto:sue@example.com">contact</a>'
              obfuskode < snippet.html > obfuscated.html
              pbpaste | obfuskode | pbcopy

            Encoding is intentionally randomized: the same input produces a different
            snippet on every run. Every snippet decodes to the same input; the tool
            verifies the round-trip before printing anything.
            """,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        )
    }

    @Option(name: .shortAndLong,
            help: "Basic mode: the email address to be obfuskoded.")
    public var email: String?

    @Option(name: [.customShort("t"), .long],
            help: "Basic mode: the visible, clickable link text (required with --email).")
    public var linkText: String?

    @Option(name: .long,
            help: "Basic mode: pop-up message shown when hovering the link.")
    public var linkTitle: String?

    @Option(name: .long,
            help: "Basic mode: a pre-set subject line for the email.")
    public var subject: String?

    @Option(name: .long,
            help: "Advanced mode: arbitrary HTML to obfuskode verbatim.")
    public var html: String?

    @Option(name: .long,
            help: "The text shown to visitors without JavaScript.")
    public var fallback: String = AppConfig.defaultFallbackMessage

    public init() {}

    // CLI-4 / CLI-5 / CLI-6 — flag-combination rules → exit 64.
    public func validate() throws {
        if email != nil && html != nil {
            throw ValidationError("--email and --html are mutually exclusive.")
        }
        if email == nil {
            if linkText != nil { throw ValidationError("--link-text requires --email.") }
            if linkTitle != nil { throw ValidationError("--link-title requires --email.") }
            if subject != nil { throw ValidationError("--subject requires --email.") }
        }
        if email != nil && linkText == nil {
            throw ValidationError("--email requires --link-text.")
        }
    }

    public func run() throws {
        try Self.execute(input: CLIInput(email: email, linkText: linkText,
                                         linkTitle: linkTitle, subject: subject,
                                         html: html, fallback: fallback),
                         io: .live)
    }
}

extension ObfuskodeCommand {
    /// Replaced in the next commit by the real I/O layer.
    static func execute(input: CLIInput, io: CLIIO) throws {}
}

public struct CLIIO: Sendable {
    public static let live = CLIIO()
}
