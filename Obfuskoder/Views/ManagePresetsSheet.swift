import SwiftUI
import ObfuskoderKit

struct ManagePresetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: PresetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(UIStrings.manageSavedValues).font(.appHeadline)
            List {
                ForEach(store.presets) { preset in
                    PresetRow(store: store, preset: preset)
                }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(width: 360, height: 240)
            HStack { Spacer(); Button(UIStrings.done) { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(16)
    }
}

private struct PresetRow: View {
    let store: PresetStore
    let preset: Preset
    @State private var editedName: String

    init(store: PresetStore, preset: Preset) {
        self.store = store
        self.preset = preset
        _editedName = State(initialValue: preset.name)
    }

    var body: some View {
        HStack {
            TextField("", text: $editedName)
                .onSubmit {
                    do { try store.rename(id: preset.id, to: editedName.trimmingCharacters(in: .whitespaces)) }
                    catch { editedName = preset.name }   // revert so the field reflects what's stored
                }
                .accessibilityLabel(Text(UIStrings.presetNameField))
            Spacer()
            Button(role: .destructive) { try? store.delete(id: preset.id) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(UIStrings.delete)
        }
    }
}
