import SwiftUI
import ObfuskoderKit

struct SavedValuesBar: View {
    @Bindable var model: AppModel
    @Environment(PresetStore.self) private var store
    @Environment(\.undoManager) private var undoManager

    @State private var showSaveSheet = false
    @State private var showManageSheet = false

    /// How many presets the menu lists before the "{n} additional items"
    /// summary row. A code-level setting, not an app preference.
    private static let menuPresetLimit = 3

    var body: some View {
        // Read presets in body (not only inside the Menu content closure) so
        // every store change re-renders, and key the Menu's identity to the
        // list so the bridged NSMenu is rebuilt — without this, renames and
        // deletes in the Manage panel leave the menu showing stale items.
        let presets = store.presets
        HStack {
            // Combo (split) button: clicking the label opens Manage Saved
            // Values; the divided indicator section opens the full menu.
            Menu(UIStrings.savedValues) {
                Button(UIStrings.saveCurrentValues) { showSaveSheet = true }
                if !presets.isEmpty {
                    Divider()
                    ForEach(presets.prefix(Self.menuPresetLimit)) { preset in
                        Button(preset.name) { model.apply(preset, undoManager: undoManager) }
                    }
                    if presets.count > Self.menuPresetLimit {
                        Button(UIStrings.additionalItems(count: presets.count - Self.menuPresetLimit)) {
                            showManageSheet = true
                        }
                    }
                    Divider()
                    Button(UIStrings.manageSavedValues) { showManageSheet = true }
                }
            } primaryAction: {
                showManageSheet = true
            }
            .fixedSize()
            .id(presets.map { $0.id.uuidString + $0.name }.joined(separator: "|"))

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
