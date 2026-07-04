import SwiftUI
import ObfuskoderKit

/// Custom encoding-delay slider (CTRL-4). The current value lives *inside* a
/// large Liquid Glass knob shaped like home plate, its point aimed at the
/// tick marks — there is no separate value readout. Drag anywhere on the
/// control, use arrow keys when focused, or adjust via accessibility.
struct DelaySlider: View {
    @Binding var value: Double
    @FocusState private var isFocused: Bool

    private let range = AppConfig.minDebounceSeconds...AppConfig.maxDebounceSeconds
    private let step = 0.05
    private let knobSize = CGSize(width: 50, height: 34)
    private let pointHeight: CGFloat = 9
    private let trackHeight: CGFloat = 4
    private let tickHeight: CGFloat = 5
    private let tickGap: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let travel = geo.size.width - knobSize.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let trackY = (knobSize.height - pointHeight) / 2 - trackHeight / 2

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: travel, height: trackHeight)
                    .offset(x: knobSize.width / 2, y: trackY)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(travel * fraction, trackHeight), height: trackHeight)
                    .offset(x: knobSize.width / 2, y: trackY)

                ForEach(1...10, id: \.self) { tenth in
                    let f = (Double(tenth) / 10 - range.lowerBound) / (range.upperBound - range.lowerBound)
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 1, height: tickHeight)
                        .offset(x: knobSize.width / 2 + travel * f, y: knobSize.height + tickGap)
                }

                knob.offset(x: travel * fraction, y: 0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isFocused = true
                        let f = min(max(0, (drag.location.x - knobSize.width / 2) / travel), 1)
                        let raw = range.lowerBound + f * (range.upperBound - range.lowerBound)
                        value = ((raw / step).rounded() * step).clamped(to: range)
                    }
            )
        }
        .frame(height: knobSize.height + tickGap + tickHeight)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        // onMoveCommand (the responder-chain moveLeft:/moveRight: path), not
        // onKeyPress: the Form's scroll view consumes raw arrow-key presses.
        .onMoveCommand { direction in
            switch direction {
            case .left: adjust(by: -step)
            case .right: adjust(by: step)
            default: break
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(UIStrings.settingsEncodingDelay))
        .accessibilityValue(Text(String(format: "%.2f seconds", value)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(by: step)
            case .decrement: adjust(by: -step)
            @unknown default: break
            }
        }
    }

    @ViewBuilder private var knob: some View {
        let label = Text(String(format: "%.2f", value))
            .font(.callout.monospacedDigit().bold())
            .padding(.bottom, pointHeight * 0.7)
            .frame(width: knobSize.width, height: knobSize.height)
        // Keyboard focus rings the knob, not the whole control (the default
        // focusable() ring boxes the entire slider area).
        let focusRing = HomePlate(pointHeight: pointHeight)
            .stroke(Color.accentColor.opacity(isFocused ? 0.8 : 0), lineWidth: 2)
        if #available(macOS 26.0, *) {
            label
                .glassEffect(.regular, in: HomePlate(pointHeight: pointHeight))
                .overlay(focusRing)
        } else {
            // Pre-Liquid-Glass fallback: translucent material knob.
            label
                .background(.ultraThinMaterial, in: HomePlate(pointHeight: pointHeight))
                .overlay(HomePlate(pointHeight: pointHeight).stroke(.quaternary, lineWidth: 1))
                .overlay(focusRing)
                .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
        }
    }

    private func adjust(by delta: Double) {
        value = ((value + delta) / step).rounded() * step
        value = value.clamped(to: range)
    }
}

/// Home-plate pentagon: flat top, squared shoulders, angled lower edges
/// meeting at a downward point.
struct HomePlate: Shape {
    var pointHeight: CGFloat = 9
    var cornerRadius: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        let shoulderY = rect.maxY - pointHeight
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                 tangent2End: CGPoint(x: rect.maxX, y: shoulderY), radius: cornerRadius)
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: shoulderY),
                 tangent2End: tip, radius: cornerRadius * 0.8)
        p.addArc(tangent1End: tip,
                 tangent2End: CGPoint(x: rect.minX, y: shoulderY), radius: 2.5)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: shoulderY),
                 tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: cornerRadius * 0.8)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                 tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: cornerRadius)
        p.closeSubpath()
        return p
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
