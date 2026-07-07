import Foundation
import ObfuskoderKit

/// The parsed invocation, decoupled from ArgumentParser for testability (SPEC-CLI §7.1).
public struct CLIInput: Equatable, Sendable {
    public var email: String?
    public var linkText: String?
    public var linkTitle: String?
    public var subject: String?
    public var html: String?
    public var fallback: String

    public init(email: String? = nil, linkText: String? = nil, linkTitle: String? = nil,
                subject: String? = nil, html: String? = nil, fallback: String) {
        self.email = email
        self.linkText = linkText
        self.linkTitle = linkTitle
        self.subject = subject
        self.html = html
        self.fallback = fallback
    }
}

/// Failure classes mapping to the SPEC-CLI §5.7 exit codes. Messages carry
/// no "obfuskode: " prefix; the output layer adds it (CLI-16).
public enum CLIFailure: Error, Equatable, Sendable {
    case usage(String)     // exit 64 via ValidationError
    case data(String)      // exit 65
    case software(String)  // exit 70
}

/// The tool's pure pipeline: validate → canonical HTML → engine encode (SPEC-CLI §5).
public enum ObfuskodeCLICore {
    /// Runs one invocation and returns the verified snippet (no trailing newline).
    /// `readStdin`/`stdinIsTTY` are injected so tests never touch a real terminal.
    public static func run(_ input: CLIInput,
                           readStdin: () throws -> Data?,
                           stdinIsTTY: () -> Bool) throws -> String {
        // CLI-12: an '@' in the fallback would fail ENC-3 on every attempt.
        guard !input.fallback.contains("@") else {
            throw CLIFailure.data("the fallback message must not contain the '@' character")
        }

        let canonical: String
        var leakCheckEmail: String?

        if let email = input.email {
            // Basic mode (CLI-10, CLI-11); same construction as the app (§5.3).
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard EmailValidator.isValid(trimmedEmail) else {
                throw CLIFailure.data("'\(email)' is not a valid email address")
            }
            // CLI-11 (revised): omitted/blank --link-text is not an error —
            // BasicFields.canonicalHTML() falls back to the email address.
            let fields = BasicFields(email: trimmedEmail,
                                     linkText: input.linkText ?? "",
                                     linkTitle: input.linkTitle ?? "",
                                     subject: input.subject ?? "")
            guard let html = fields.canonicalHTML() else {
                // Unreachable after the guards above; defensive.
                throw CLIFailure.data("the basic fields could not be combined into a link")
            }
            canonical = html
            leakCheckEmail = trimmedEmail                       // CLI-9
        } else if let html = input.html {
            canonical = try advancedInput(html)
        } else {
            canonical = try advancedInput(readFromStdin(readStdin: readStdin,
                                                        stdinIsTTY: stdinIsTTY))
        }

        let engine = ObfuskodeEngine(fallbackMessage: input.fallback)
        do {
            return try engine.encode(canonical, email: leakCheckEmail).html
        } catch ObfuskodeError.selfCheckFailed(.fallbackContainsPlaintext) {
            // §5.8 (revised): the user's data to fix — exit 65, not 70.
            throw CLIFailure.data("the fallback message contains the input text (the snippet would leak it)")
        } catch ObfuskodeError.selfCheckFailed(let cause) {
            throw CLIFailure.software("the encoded snippet failed its self-check (\(describe(cause))); please report this bug")
        } catch ObfuskodeError.selfCheckFailedRepeatedly(let last) {
            throw CLIFailure.software("the encoded snippet failed its self-check repeatedly (last failure: \(describe(last))); please report this bug")
        }
    }

    private static func describe(_ error: SelfCheckError) -> String {
        switch error {
        case .fallbackContainsPlaintext: "the fallback message contains the input text"
        case .plaintextLeak: "plaintext leaked into the snippet"
        case .atSignPresent: "an '@' remained in the snippet"
        case .roundTripMismatch: "the decoded output did not match the input"
        case .engineError(let message): "JavaScript engine error: \(message)"
        }
    }

    /// CLI-13: Advanced input is trimmed and must be non-empty.
    private static func advancedInput(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CLIFailure.data("no HTML to obfuskode (input is empty)")
        }
        return trimmed
    }

    /// CLI-7 / CLI-14: stdin is read only when it is not a TTY.
    private static func readFromStdin(readStdin: () throws -> Data?,
                                      stdinIsTTY: () -> Bool) throws -> String {
        guard !stdinIsTTY() else {
            throw CLIFailure.usage("missing input: pass --email or --html, or pipe HTML to standard input")
        }
        let data: Data?
        do {
            data = try readStdin()
        } catch {
            // A genuine read failure is not the same as no input (CLI-14).
            throw CLIFailure.data("could not read standard input: \(error)")
        }
        guard let data, !data.isEmpty else {
            throw CLIFailure.data("no HTML to obfuskode (input is empty)")
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CLIFailure.data("standard input is not valid UTF-8")
        }
        return text
    }
}
