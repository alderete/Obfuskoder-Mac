import SwiftUI
import ObfuskoderKit

/// Toolbar mode switcher. Custom control because neither SwiftUI's segmented
/// Picker nor NSSegmentedControl (`selectedSegmentBezelColor` is ignored on
/// modern macOS) will tint the selected segment with the accent color
/// (COLOR-1). Accessibility is hand-built: a contained group labeled
/// "Input mode" (test 16.3) whose segments are labeled buttons carrying the
/// selected trait. (`accessibilityRepresentation` with a Picker was tried and
/// produced an unlabeled tab group — worse than this.)
struct ModePicker: View {
    let mode: FormMode
    let onSelect: (FormMode) -> Void
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // No track of our own: the toolbar's glass capsule is the track, and a
        // taller chip keeps its cap curvature concentric with that capsule.
        // A separate inner capsule never nests cleanly inside the system one
        // (its horizontal padding exceeds its vertical padding).
        HStack(spacing: 2) {
            segment(UIStrings.basic, .basic)
            segment(UIStrings.advanced, .advanced)
        }
        // 4pt measured-in: puts the chip's cap center on the glass capsule's
        // cap center, so the gap stays even around the curve.
        .padding(.horizontal, 4)
        // Slide the selection lozenge implicitly off the value. This is
        // deliberately NOT a `withAnimation` at the tap: on macOS (Xcode 26.6)
        // a withAnimation transaction does not reach NSToolbar-hosted content
        // and snaps, whereas `.animation(value:)` animates it — and it covers
        // every trigger uniformly (toolbar click, and a mode switch from Apply
        // Saved Values). Honors Reduce Motion. (Verified in a SwiftUI testbed.)
        .animation(reduceMotion ? nil : .default, value: mode)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(UIStrings.modeLabel))
    }

    private func segment(_ title: String, _ value: FormMode) -> some View {
        Button {
            // Animation is driven implicitly by `.animation(value: mode)` on the
            // container (see body), so click and any other trigger behave alike.
            onSelect(value)
        } label: {
            Text(title)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(mode == value ? .white : .primary)
                .background {
                    if mode == value {
                        Capsule().fill(Color.accentColor)
                            .matchedGeometryEffect(id: "selected", in: selection)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(mode == value ? [.isSelected] : [])
    }
}
