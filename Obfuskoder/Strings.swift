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

    // Command-line tool install (SPEC-CLI §6)
    static let installCLITool = String(localized: "Install Command Line Tool…")
    static let cliInstallPrompt = String(localized: "Install")
    static let cliInstallPanelMessage = String(localized: "Choose where to install the obfuskode command-line tool. A symbolic link to the tool inside Obfuskoder will be created in this folder.")
    static let cliMoveToApplicationsTitle = String(localized: "Move Obfuskoder to your Applications folder first.")
    static let cliMoveToApplicationsBody = String(localized: "Obfuskoder is running from a temporary location. A command-line tool installed now would stop working. Move Obfuskoder to your Applications folder, then choose Install Command Line Tool again.")
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

    // Command-line tool help window (SPEC-CLI §11.2)
    static let cliHelpMenu = String(localized: "Command-Line Tool Help")
    static let cliHelpWindowTitle = String(localized: "Command-Line Tool")
    static let cliHelpIntro = String(localized: "Obfuskoder includes obfuskode, a command-line version of the encoder, for scripts and pipelines.")
    static let cliHelpInstall = String(localized: "Install it with Obfuskoder ▸ Install Command Line Tool…, then run it from Terminal:")
    static let cliHelpOutro = String(localized: "The obfuscated snippet is written to standard output. For all options, run obfuskode --help.")

    // Helpers
    static func hintAccessibilityLabel(for field: String) -> String {
        String(localized: "\(field) help")
    }
}
