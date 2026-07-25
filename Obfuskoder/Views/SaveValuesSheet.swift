import SwiftUI
import ObfuskoderKit

struct SaveValuesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: PresetStore
    let payload: PresetPayload

    @State private var name = ""
    @State private var duplicate = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.presetNamePrompt).font(.appHeadline)
            // AuxTextField (not a plain TextField): it clears its native-undo
            // stack on focus / programmatic reset, so a "Typing" action from a
            // prior presentation can't survive a Cancel-then-reopen and crash
            // when invoked against the reset name (test 10.2).
            AuxTextField(text: $name, clearsUndoOnFocus: true)
                .frame(width: 280)
                .onChange(of: name) { duplicate = false; saveError = nil }
                .accessibilityLabel(Text(UIStrings.presetNamePrompt))
            if duplicate {
                Text(UIStrings.presetNameDuplicate).foregroundStyle(.red).font(.caption)
            }
            if let saveError {
                Text(saveError).foregroundStyle(.red).font(.caption)
            }
            HStack {
                Spacer()
                Button(UIStrings.cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                if duplicate {
                    Button(UIStrings.replace) { replaceExisting() }.keyboardShortcut(.defaultAction)
                } else {
                    Button(UIStrings.save) { trySave() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(20)
    }

    private func trySave() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        do { _ = try store.save(name: trimmed, payload: payload); dismiss() }
        catch PresetError.duplicateName(_) { duplicate = true }
        catch { saveError = UIStrings.presetSaveFailed }
    }

    private func replaceExisting() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let existing = store.presets.first(where: { $0.name == trimmed }) else { dismiss(); return }
        do { try store.replace(id: existing.id, name: trimmed, payload: payload); dismiss() }
        catch { saveError = UIStrings.presetSaveFailed }
    }
}
