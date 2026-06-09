import SwiftUI

enum UIStrings {
    static let appName = String(localized: "Obfuskoder")

    // Mode
    static let basic = String(localized: "Basic")
    static let advanced = String(localized: "Advanced")

    // Basic fields
    static let emailLabel = String(localized: "Email address")
    static let linkTextLabel = String(localized: "Link text")
    static let linkTitleLabel = String(localized: "Link title")
    static let subjectLabel = String(localized: "Subject")
    static let optional = String(localized: "optional")

    // Hints (SPEC §6.3)
    static let emailHint = String(localized: "The email address to be obfuskoded.")
    static let linkTextHint = String(localized: "The text users will see and click. Also obfuskoded, so you can repeat your email address.")
    static let linkTitleHint = String(localized: "Pop-up message seen when the mouse hovers over the link.")
    static let subjectHint = String(localized: "A pre-set subject line for the email. Supported by most email clients.")
    static let advancedLabel = String(localized: "HTML to obfuskode")
    static let advancedHint = String(localized: "Paste arbitrary HTML. Whatever you enter will round-trip through Obfuskoder verbatim. (Surrounding whitespace is trimmed.)")

    // Result
    static let snippetHeading = String(localized: "Obfuskoded snippet")
    static let updatesAsYouType = String(localized: "updates as you type")
    static let copy = String(localized: "Copy")
    static let copySnippet = String(localized: "Copy Snippet")
    static let copied = String(localized: "Copied")
    static let previewHeading = String(localized: "Preview")
    static let previewNonInteractive = String(localized: "Preview is non-interactive")
    static let showDecodedSource = String(localized: "Show decoded source")
    static let emptyResult = String(localized: "Enter a valid email or HTML to generate a snippet.")
    static let encodeFailed = String(localized: "Could not generate a valid snippet. Check your input.")

    // Saved values (working label)
    static let savedValues = String(localized: "Saved values")
    static let saveCurrentValues = String(localized: "Save Current Values…")
    static let manageSavedValues = String(localized: "Manage Saved Values…")
    static let clearForm = String(localized: "Clear Form")
    static let modeLabel = String(localized: "Input mode")
    static let toggleDecodedSource = String(localized: "Show/Hide Decoded Source")
    static let presetNameField = String(localized: "Preset name")

    // Sheets
    static let presetNamePrompt = String(localized: "Name for these values:")
    static let presetNameDuplicate = String(localized: "A saved set with that name already exists.")
    static let presetSaveFailed = String(localized: "Could not save these values. Check available disk space and try again.")
    static let replace = String(localized: "Replace")
    static let save = String(localized: "Save")
    static let cancel = String(localized: "Cancel")
    static let delete = String(localized: "Delete")
    static let done = String(localized: "Done")

    // Settings
    static let settingsEncodingDelay = String(localized: "Encoding delay")
    static let settingsFallbackMessage = String(localized: "No-JavaScript fallback message")

    // Helpers
    static func hintAccessibilityLabel(for field: String) -> String {
        String(localized: "\(field) help")
    }
}
