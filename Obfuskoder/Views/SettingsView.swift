import SwiftUI
import AppKit
import ObfuskoderKit

struct SettingsView: View {
    @AppStorage(SettingsKeys.debounceSeconds) private var debounce = AppConfig.defaultDebounceSeconds
    @AppStorage(SettingsKeys.fallbackMessage) private var fallback = AppConfig.defaultFallbackMessage

    var body: some View {
        Form {
            Section(UIStrings.settingsEncodingDelay) {
                HStack(spacing: 12) {
                    Text("0.1s").font(.caption).foregroundStyle(.secondary)
                    DelaySlider(value: $debounce)
                    Text("1.0s").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            Section(UIStrings.settingsFallbackMessage) {
                // Ghost text: a blank setting falls back to the default
                // message (applied in ContentView.syncSettings) — CTRL-6.
                MacTextField(text: $fallback,
                             placeholder: AppConfig.defaultFallbackMessage,
                             formatter: NoAtSignFormatter())
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
