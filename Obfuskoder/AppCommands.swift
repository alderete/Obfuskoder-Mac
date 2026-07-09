import SwiftUI
import ObfuskoderKit

extension Notification.Name {
    static let saveCurrentValues = Notification.Name("ObfuskoderSaveCurrentValues")
    static let clearForm = Notification.Name("ObfuskoderClearForm")
}

struct AppCommands: Commands {
    let model: AppModel
    let softwareUpdater: SoftwareUpdater
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // About Obfuskoder — standard panel + custom credits (MENU-1)
        CommandGroup(replacing: .appInfo) {
            Button(UIStrings.aboutMenuItem) { AboutPanel.show() }
        }
        // Obfuskoder ▸ Check for Updates… — standard spot, just below About.
        CommandGroup(after: .appInfo) {
            CheckForUpdatesView(updater: softwareUpdater)
        }
        // Obfuskoder ▸ Install Command Line Tool… (SPEC-CLI §6.1)
        CommandGroup(after: .appSettings) {
            Button(UIStrings.installCLITool) { CLIToolInstaller.run() }
        }
        // View ▸ Basic / Advanced / Show-Hide Decoded Source
        CommandGroup(after: .toolbar) {
            // Radio-style Toggles: each renders a checkmark on the active mode
            // (HIG for mutually-exclusive modes) while keeping ⌘1/⌘2. Turning
            // one on switches the mode; the other's checkmark clears. Pressing
            // the active mode's shortcut is a harmless no-op.
            Toggle(UIStrings.basic, isOn: modeBinding(.basic))
                .keyboardShortcut("1", modifiers: .command)
            Toggle(UIStrings.advanced, isOn: modeBinding(.advanced))
                .keyboardShortcut("2", modifiers: .command)
            Button(model.showDecodedSource ? UIStrings.hideDecodedSourceMenu
                                           : UIStrings.showDecodedSourceMenu) {
                model.showDecodedSource.toggle()
            }
            .disabled(model.snippetText == nil)
        }
        CommandGroup(after: .newItem) {
            Button(UIStrings.saveCurrentValues) {
                NotificationCenter.default.post(name: .saveCurrentValues, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)
            // Nothing worth saving when the active form is empty (also avoids
            // creating a blank preset).
            .disabled(model.form.activeIsEmpty)
        }
        // Edit ▸ Copy Snippet (⇧⌘C) + Clear Form (⌘K)
        // The app's own commands, grouped together and fenced off from the standard
        // Edit commands by separators above and below.
        CommandGroup(after: .pasteboard) {
            Divider()
            Button(UIStrings.copySnippet, systemImage: "arrow.right.doc.on.clipboard") {
                model.copySnippet()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(model.snippetText == nil)
            Button(UIStrings.clearForm, systemImage: "clear") {
                NotificationCenter.default.post(name: .clearForm, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(model.form.activeIsEmpty)
            Divider()
        }
        // Help ▸ Obfuskoder Help (⌘?, replaces the default help-book item —
        // MENU-4) and Help ▸ Obfuskoder CLI Help (SPEC-CLI §11.2)
        CommandGroup(replacing: .help) {
            Button(UIStrings.appHelpMenu) { openWindow(id: "app-help") }
                .keyboardShortcut("?", modifiers: .command)
        }
        CommandGroup(after: .help) {
            Button(UIStrings.cliHelpMenu) { openWindow(id: "cli-help") }
        }
    }

    /// A Bool binding that is `on` for the given mode; setting it on selects
    /// that mode (setting it off does nothing — radio, not independent toggles).
    private func modeBinding(_ mode: FormMode) -> Binding<Bool> {
        Binding(
            get: { model.form.mode == mode },
            set: { if $0 { model.form.mode = mode; model.scheduleEncode() } })
    }
}
