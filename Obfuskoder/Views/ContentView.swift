import SwiftUI
import ObfuskoderKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(PresetStore.self) private var store

    @AppStorage(SettingsKeys.debounceSeconds) private var debounce = AppConfig.defaultDebounceSeconds
    @AppStorage(SettingsKeys.fallbackMessage) private var fallback = AppConfig.defaultFallbackMessage

    @State private var showSaveSheet = false

    var body: some View {
        @Bindable var model = model
        HSplitView {
            InputPane(model: model)
                .frame(minWidth: 320)
            ResultPane(model: model)
                .frame(minWidth: 320)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $model.form.mode) {
                    Text(UIStrings.basic).tag(FormMode.basic)
                    Text(UIStrings.advanced).tag(FormMode.advanced)
                }
                .pickerStyle(.segmented)
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
        .sheet(isPresented: $showSaveSheet) {
            SaveValuesSheet(store: store, payload: model.form.payload())
        }
    }

    private func syncSettings() {
        model.debounceSeconds = debounce
        model.fallbackMessage = fallback
        model.scheduleEncode()
    }
}
