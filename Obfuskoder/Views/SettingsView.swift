import SwiftUI
import ObfuskoderKit

struct SettingsView: View {
    @AppStorage(SettingsKeys.debounceSeconds) private var debounce = AppConfig.defaultDebounceSeconds
    @AppStorage(SettingsKeys.fallbackMessage) private var fallback = AppConfig.defaultFallbackMessage

    var body: some View {
        Form {
            Section {
                Slider(value: $debounce,
                       in: AppConfig.minDebounceSeconds...AppConfig.maxDebounceSeconds,
                       step: 0.05) {
                    Text(UIStrings.settingsEncodingDelay)
                } minimumValueLabel: { Text("0.1s") } maximumValueLabel: { Text("1.0s") }
                Text(String(format: "%.2fs", debounce)).foregroundStyle(.secondary).font(.caption)
            }
            Section(UIStrings.settingsFallbackMessage) {
                TextField("", text: $fallback)
                    .onChange(of: fallback) { fallback = fallback.replacingOccurrences(of: "@", with: "") }
                    .accessibilityLabel(Text(UIStrings.settingsFallbackMessage))
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding(20)
    }
}
