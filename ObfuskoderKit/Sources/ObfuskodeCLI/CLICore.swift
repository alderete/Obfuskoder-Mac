import Foundation

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
