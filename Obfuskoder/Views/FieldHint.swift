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
            // Fixed width + vertical fixedSize so the popover's height is
            // measured for the wrapped text — maxWidth alone clips long hints
            // to the single-line height the popover measured first (FORM-5).
            Text(hint)
                .font(.callout)
                .frame(width: 256, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
        }
    }
}
