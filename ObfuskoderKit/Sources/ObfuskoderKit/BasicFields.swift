import Foundation

public struct BasicFields: Codable, Equatable, Sendable {
    public var email: String
    public var linkText: String
    public var linkTitle: String
    public var subject: String

    public init(email: String = "", linkText: String = "",
                linkTitle: String = "", subject: String = "") {
        self.email = email
        self.linkText = linkText
        self.linkTitle = linkTitle
        self.subject = subject
    }

    /// Canonical `<a>` HTML, or nil when the email is invalid (SPEC §6.3).
    /// Empty/whitespace link text falls back to the email address itself —
    /// half the time the link text is just the email repeated.
    public func canonicalHTML() -> String? {
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailValidator.isValid(emailTrimmed) else { return nil }
        let trimmedLinkText = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmedLinkText.isEmpty ? emailTrimmed : trimmedLinkText

        let title = linkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subj = subject.trimmingCharacters(in: .whitespacesAndNewlines)

        var href = "mailto:" + percentEncodeMailtoAddress(emailTrimmed)
        if !subj.isEmpty { href += "?subject=" + percentEncodeComponent(subj) }

        var html = "<a href=\"" + htmlEscapeAttribute(href) + "\""
        if !title.isEmpty { html += " title=\"" + htmlEscapeAttribute(title) + "\"" }
        html += ">" + htmlEscapeText(text) + "</a>"
        return html
    }
}
