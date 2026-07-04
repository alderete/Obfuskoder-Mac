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
    static let emptySnippet = String(localized: "Enter form values to generate a snippet")
    static let emptyPreview = String(localized: "Preview renders once there's a snippet")
    static let encodeFailed = String(localized: "Could not generate a valid snippet. Check your input.")

    // Saved values
    static let savedValues = String(localized: "Saved Values")
    // Panel title has no ellipsis; the menu item that opens it keeps one (HIG).
    static let manageSavedValuesTitle = String(localized: "Manage Saved Values")
    /// "{n} additional item(s)". Explicit singular/plural keys — the automatic
    /// grammar-agreement markup (^[…](inflect: true)) failed to pluralize here.
    static func additionalItems(count: Int) -> String {
        count == 1
            ? String(localized: "1 additional item")
            : String(localized: "\(count) additional items")
    }
    static let manageEmptyMessage = String(localized: "No saved values yet")
    static let moveUp = String(localized: "Move Up")
    static let moveDown = String(localized: "Move Down")
    static let saveCurrentValues = String(localized: "Save Current Values…")
    static let manageSavedValues = String(localized: "Manage Saved Values…")
    static let clearForm = String(localized: "Clear Form")
    static let modeLabel = String(localized: "Input mode")
    static let showDecodedSourceMenu = String(localized: "Show Decoded Source")
    static let hideDecodedSourceMenu = String(localized: "Hide Decoded Source")
    static let presetNameField = String(localized: "Preset name")

    // About (MENU-1)
    static let aboutMenuItem = String(localized: "About Obfuskoder")
    static let aboutTagline = String(localized: "Turn an email address into a JavaScript-obfuscated snippet that bots (maybe) can't read but visitors can.")
    static let aboutAttribution = String(localized: "Inspired by Enkoder.")

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

    // Command-line tool install (SPEC-CLI §6)
    static let installCLITool = String(localized: "Install Command Line Tool…")
    static let cliInstallPrompt = String(localized: "Install")
    static let cliInstallPanelMessage = String(localized: "Choose where to install the obfuskode command-line tool. A symbolic link to the tool inside Obfuskoder will be created in this folder.")
    static let cliMoveToApplicationsTitle = String(localized: "Move Obfuskoder to your Applications folder first.")
    static let cliMoveToApplicationsBody = String(localized: "Obfuskoder is running from a temporary location. A command-line tool installed now would stop working. Move Obfuskoder to your Applications folder, then choose Install Command Line Tool again.")
    static let cliMissingToolTitle = String(localized: "The command-line tool is missing from this copy of Obfuskoder.")
    static let cliMissingToolBody = String(localized: "Reinstall Obfuskoder, then choose Install Command Line Tool again.")
    static let cliReplaceTitle = String(localized: "An item named \u{201C}obfuskode\u{201D} already exists in this folder.")
    static let cliReplaceBody = String(localized: "Replacing it will remove the existing item and create a link to the tool inside Obfuskoder.")
    static let cliFailTitle = String(localized: "Obfuskoder couldn't install the command-line tool there.")
    static let cliFailReasonDirectory = String(localized: "A folder named \u{201C}obfuskode\u{201D} is in the way.")
    static func cliFailReasonPermission(folder: String) -> String {
        String(localized: "You don't have permission to write to \(folder).")
    }
    static func cliFailBody(reason: String, command: String) -> String {
        String(localized: "\(reason) You can install it yourself by running this command in Terminal:\n\n\(command)")
    }
    static let cliCopyCommand = String(localized: "Copy Command")
    static let cliSuccessTitle = String(localized: "The obfuskode command-line tool was installed.")
    static func cliSuccessBody(target: String) -> String {
        String(localized: "A link was created at \(target).")
    }
    static func cliAlreadyInstalledBody(target: String) -> String {
        String(localized: "The tool is already installed at \(target).")
    }
    static func cliPathHint(folder: String) -> String {
        String(localized: "If \(folder) isn't in your shell's PATH, add it to run obfuskode by name.")
    }

    // App help window (MENU-4) — content distilled from README/SPECIFICATION.
    // Inline `code`/**bold** markdown renders via Text(inlineMarkdown:).
    static let appHelpMenu = String(localized: "Obfuskoder Help")
    static let appHelpWindowTitle = String(localized: "Obfuskoder Help")
    static let appHelpIntro = String(localized: "Obfuskoder turns an email address — or an arbitrary HTML snippet — into an obfuscated HTML+JavaScript snippet you can paste into your own web page. Visitors see a normal mail link; email-harvesting bots that don't run JavaScript see only opaque code.")
    static let appHelpModes = String(localized: "**Basic** (⌘1) builds the snippet from an email address, link text, and optional link title and subject. **Advanced** (⌘2) obfuscates any HTML you paste — whatever you enter round-trips verbatim.")
    static let appHelpPreview = String(localized: "The snippet updates as you type, and the Preview runs it in a real web view — what you see is the decoded result, not a mock-up. The preview is deliberately non-interactive: clicking the link won't open Mail. Show Decoded Source reveals the exact HTML the snippet writes.")
    static let appHelpGuarantee = String(localized: "The snippet never contains the @ character or a readable copy of the address — every encode is verified by executing it. Encoding is intentionally randomized: the same input produces a different snippet each time, and every snippet decodes identically.")
    static let appHelpSaved = String(localized: "Use Saved Values (⌘S) to keep sets of frequently used values and recall them later.")
    static let appHelpPrivacy = String(localized: "Obfuskoder makes no network connections of any kind. Saved values and settings are stored locally only.")
    static let appHelpCLIPointer = String(localized: "For scripts and pipelines, Obfuskoder includes the `obfuskode` command-line tool — see Help ▸ Obfuskoder CLI Help.")

    // Command-line tool help window (SPEC-CLI §11.2)
    // Inline `code` markdown renders monospaced in CLIHelpView (MENU-5).
    static let cliHelpMenu = String(localized: "Obfuskoder CLI Help")
    static let cliHelpWindowTitle = String(localized: "Obfuskoder CLI Help")
    static let cliHelpIntro = String(localized: "Obfuskoder includes `obfuskode`, a command-line version of the encoder, for scripts and pipelines.")
    static let cliHelpInstall = String(localized: "Install it with Obfuskoder ▸ Install Command Line Tool…, then run it from Terminal:")
    static let cliHelpOutro = String(localized: "The obfuscated snippet is written to standard output. For all options, run `obfuskode --help`.")

    // Helpers
    static func hintAccessibilityLabel(for field: String) -> String {
        String(localized: "\(field) help")
    }
}
