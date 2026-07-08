import SwiftUI
import ObfuskoderKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(PresetStore.self) private var store

    @Environment(\.undoManager) private var undoManager
    @AppStorage(SettingsKeys.debounceSeconds) private var debounce = AppConfig.defaultDebounceSeconds
    @AppStorage(SettingsKeys.fallbackMessage) private var fallback = AppConfig.defaultFallbackMessage

    @State private var showSaveSheet = false

    var body: some View {
        @Bindable var model = model
        HSplitView {
            InputPane(model: model)
                // With labels above the fields, content compresses gracefully;
                // 320 keeps fields ≥288pt wide. If the form layout changes,
                // re-verify with a divider drag that nothing clips (WIN-1).
                .frame(minWidth: 320)
            ResultPane(model: model)
                .frame(minWidth: 320)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                ModePicker(mode: $model.form.mode)
                    .fixedSize()
            }
        }
        .onAppear { syncSettings() }
        .onChange(of: model.form) { model.scheduleEncode() }
        .onChange(of: debounce) { syncSettings() }
        .onChange(of: fallback) { syncSettings() }
        .onReceive(NotificationCenter.default.publisher(for: .saveCurrentValues)) { _ in
            showSaveSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearForm)) { _ in
            model.clearActiveForm(undoManager: undoManager)
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveValuesSheet(store: store, payload: model.form.payload())
        }
    }

    private func syncSettings() {
        // Clamp and sanitize at this single choke point: values can arrive from
        // `defaults write` bypassing the Settings field's own validation, and an
        // out-of-range debounce or an '@' in the fallback would otherwise make
        // every encode fail or the app appear dead.
        model.debounceSeconds = min(max(debounce, AppConfig.minDebounceSeconds),
                                    AppConfig.maxDebounceSeconds)
        let sanitized = FallbackSanitizer.strippingAtSigns(from: fallback, cursor: 0).text
        // Blank setting means "use the default message" (CTRL-6).
        model.fallbackMessage = sanitized.trimmingCharacters(in: .whitespaces).isEmpty
            ? AppConfig.defaultFallbackMessage : sanitized
        model.scheduleEncode()
    }
}
