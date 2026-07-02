import SwiftUI
import AppKit
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
                MacTextField(text: $fallback, formatter: NoAtSignFormatter())
                    // Safety net only: the formatter blocks typed/pasted "@";
                    // this covers values that reach defaults from outside the UI.
                    .onChange(of: fallback) { fallback = fallback.replacingOccurrences(of: "@", with: "") }
                    .accessibilityLabel(Text(UIStrings.settingsFallbackMessage))
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding(20)
    }
}

/// Rejects "@" at the field-editor level, so the character never enters the
/// text and the insertion point never moves; beeps so the user notices the
/// rejection. `string(for:)`/`getObjectValue` are the pass-through plumbing
/// NSTextField requires of any Formatter.
nonisolated final class NoAtSignFormatter: Formatter {
    override func string(for obj: Any?) -> String? { obj as? String }

    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        obj?.pointee = string as NSString
        return true
    }

    override func isPartialStringValid(_ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>,
                                       proposedSelectedRange proposedSelRangePtr: NSRangePointer?,
                                       originalString origString: String,
                                       originalSelectedRange origSelRange: NSRange,
                                       errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        let proposed = partialStringPtr.pointee as String
        guard proposed.contains("@") else { return true }
        NSSound.beep()
        let cursor = proposedSelRangePtr?.pointee.location ?? (proposed as NSString).length
        let sanitized = FallbackSanitizer.strippingAtSigns(from: proposed, cursor: cursor)
        partialStringPtr.pointee = sanitized.text as NSString
        proposedSelRangePtr?.pointee = NSRange(location: sanitized.cursor, length: 0)
        return false
    }
}
