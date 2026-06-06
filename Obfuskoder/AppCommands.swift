import SwiftUI
import ObfuskoderKit

extension Notification.Name {
    static let saveCurrentValues = Notification.Name("ObfuskoderSaveCurrentValues")
}

struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        // View ▸ Basic / Advanced
        CommandGroup(after: .toolbar) {
            Button(UIStrings.basic) { model.form.mode = .basic; model.scheduleEncode() }
                .keyboardShortcut("1", modifiers: .command)
            Button(UIStrings.advanced) { model.form.mode = .advanced; model.scheduleEncode() }
                .keyboardShortcut("2", modifiers: .command)
        }
        CommandGroup(after: .newItem) {
            Button(UIStrings.saveCurrentValues) {
                NotificationCenter.default.post(name: .saveCurrentValues, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)
        }
        // Edit ▸ Copy Snippet (⇧⌘C) + Clear Form (⌘K)
        CommandGroup(after: .pasteboard) {
            Button(UIStrings.copy) {
                if let html = model.snippetText {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(html, forType: .string)
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(model.snippetText == nil)

            Button(UIStrings.clearForm) { model.clearActiveForm() }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(model.form.activeIsEmpty)
        }
    }
}
