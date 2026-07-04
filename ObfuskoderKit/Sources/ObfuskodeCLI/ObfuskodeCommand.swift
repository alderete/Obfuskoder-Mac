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
            help: "Basic mode: the visible, clickable link text (defaults to the email address).")
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
    }

    public func run() throws {
        try Self.execute(input: CLIInput(email: email, linkText: linkText,
                                         linkTitle: linkTitle, subject: subject,
                                         html: html, fallback: fallback),
                         io: .live)
    }
}

/// Injected I/O seams (SPEC-CLI §7.1): tests capture; `.live` is the process.
public struct CLIIO {
    public var readStdin: () -> Data?
    public var stdinIsTTY: () -> Bool
    public var writeOut: (String) -> Void
    public var writeErr: (String) -> Void

    public init(readStdin: @escaping () -> Data?,
                stdinIsTTY: @escaping () -> Bool,
                writeOut: @escaping (String) -> Void,
                writeErr: @escaping (String) -> Void) {
        self.readStdin = readStdin
        self.stdinIsTTY = stdinIsTTY
        self.writeOut = writeOut
        self.writeErr = writeErr
    }

    public static var live: CLIIO {
        CLIIO(
            readStdin: { try? FileHandle.standardInput.readToEnd() },
            stdinIsTTY: { isatty(STDIN_FILENO) == 1 },
            writeOut: { FileHandle.standardOutput.write(Data($0.utf8)) },
            writeErr: { FileHandle.standardError.write(Data($0.utf8)) }
        )
    }
}

extension ObfuskodeCommand {
    /// Runs the pipeline and maps failures to the §5.7 exit codes.
    /// Usage failures re-throw as ValidationError so ArgumentParser prints
    /// usage and exits 64; data/software failures write "obfuskode: <msg>"
    /// to stderr and exit 65 / 70.
    public static func execute(input: CLIInput, io: CLIIO) throws {
        do {
            let snippet = try ObfuskodeCLICore.run(input,
                                                   readStdin: io.readStdin,
                                                   stdinIsTTY: io.stdinIsTTY)
            io.writeOut(snippet + "\n")                       // CLI-15
        } catch let failure as CLIFailure {
            switch failure {
            case .usage(let message):
                throw ValidationError(message)
            case .data(let message):
                io.writeErr("obfuskode: \(message)\n")
                throw ExitCode(65)
            case .software(let message):
                io.writeErr("obfuskode: \(message)\n")
                throw ExitCode(70)
            }
        }
    }
}
