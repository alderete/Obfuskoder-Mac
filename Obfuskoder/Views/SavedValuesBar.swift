import SwiftUI
import ObfuskoderKit

struct SavedValuesBar: View {
    @Bindable var model: AppModel
    @Environment(PresetStore.self) private var store

    @State private var showSaveSheet = false
    @State private var showManageSheet = false

    var body: some View {
        HStack {
            Menu(UIStrings.savedValues) {
                Button(UIStrings.saveCurrentValues) { showSaveSheet = true }
                if !store.presets.isEmpty {
                    Divider()
                    ForEach(store.presets) { preset in
                        Button(preset.name) { model.apply(preset) }
                    }
                    Divider()
                    Button(UIStrings.manageSavedValues) { showManageSheet = true }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button(UIStrings.clearForm) {
                NotificationCenter.default.post(name: .clearForm, object: nil)
            }
            .disabled(model.form.activeIsEmpty)
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveValuesSheet(store: store, payload: model.form.payload())
        }
        .sheet(isPresented: $showManageSheet) {
            ManagePresetsSheet(store: store)
        }
    }
}
