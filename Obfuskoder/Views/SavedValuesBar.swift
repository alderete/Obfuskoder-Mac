import SwiftUI
import ObfuskoderKit

struct SavedValuesBar: View {
    @Bindable var model: AppModel
    @Environment(PresetStore.self) private var store

    @State private var showSaveSheet = false
    @State private var showManageSheet = false

    var body: some View {
        HStack {
            // Combo (split) button: clicking the label opens Manage Saved
            // Values; the divided indicator section opens the full menu.
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
            } primaryAction: {
                showManageSheet = true
            }
            .fixedSize()

            Spacer()

            // Deliberately not accent-tinted: clearing is a secondary action;
            // Copy is the pane's one prominent button (COLOR-2).
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
