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

    /// Canonical `<a>` HTML, or nil when the email is invalid or link text is empty (SPEC §6.3).
    public func canonicalHTML() -> String? {
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailValidator.isValid(emailTrimmed) else { return nil }
        let text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let title = linkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subj = subject.trimmingCharacters(in: .whitespacesAndNewlines)

        var href = "mailto:" + emailTrimmed
        if !subj.isEmpty { href += "?subject=" + percentEncodeComponent(subj) }

        var html = "<a href=\"" + htmlEscapeAttribute(href) + "\""
        if !title.isEmpty { html += " title=\"" + htmlEscapeAttribute(title) + "\"" }
        html += ">" + htmlEscapeText(text) + "</a>"
        return html
    }
}
