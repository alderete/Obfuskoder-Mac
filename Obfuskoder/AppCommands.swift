import SwiftUI
import ObfuskoderKit

extension Notification.Name {
    static let saveCurrentValues = Notification.Name("ObfuskoderSaveCurrentValues")
    static let clearForm = Notification.Name("ObfuskoderClearForm")
}

struct AppCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // Obfuskoder ▸ Install Command Line Tool… (SPEC-CLI §6.1)
        CommandGroup(after: .appSettings) {
            Button(UIStrings.installCLITool) { CLIToolInstaller.run() }
        }
        // View ▸ Basic / Advanced / Show-Hide Decoded Source
        CommandGroup(after: .toolbar) {
            Button(UIStrings.basic) { model.form.mode = .basic; model.scheduleEncode() }
                .keyboardShortcut("1", modifiers: .command)
            Button(UIStrings.advanced) { model.form.mode = .advanced; model.scheduleEncode() }
                .keyboardShortcut("2", modifiers: .command)
            Button(UIStrings.toggleDecodedSource) { model.showDecodedSource.toggle() }
                .disabled(model.snippetText == nil)
        }
        CommandGroup(after: .newItem) {
            Button(UIStrings.saveCurrentValues) {
                NotificationCenter.default.post(name: .saveCurrentValues, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)
        }
        // Edit ▸ Copy Snippet (⇧⌘C) + Clear Form (⌘K)
        // The app's own commands, grouped together and fenced off from the standard
        // Edit commands by separators above and below.
        CommandGroup(after: .pasteboard) {
            Divider()
            Button(UIStrings.copySnippet) { model.copySnippet() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model.snippetText == nil)
            Button(UIStrings.clearForm) {
                NotificationCenter.default.post(name: .clearForm, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(model.form.activeIsEmpty)
            Divider()
        }
        // Help ▸ Command-Line Tool Help (SPEC-CLI §11.2)
        CommandGroup(after: .help) {
            Button(UIStrings.cliHelpMenu) { openWindow(id: "cli-help") }
        }
    }
}
