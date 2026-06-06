import SwiftUI

/// Trailing info.circle affordance: help tag on hover, popover on click, accessible to VoiceOver (SPEC §6.3).
struct FieldHint: View {
    let fieldLabel: String
    let hint: String
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(hint)
        .accessibilityLabel(UIStrings.hintAccessibilityLabel(for: fieldLabel))
        .accessibilityHint(hint)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            Text(hint)
                .font(.callout)
                .padding(12)
                .frame(maxWidth: 280)
        }
    }
}
