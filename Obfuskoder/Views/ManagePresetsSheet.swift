import SwiftUI
import ObfuskoderKit

/// Manage Saved Values panel (MAC-1/MAC-2). Rows carry a gripper that drags
/// with live, animated reordering — the lifted row follows the pointer and the
/// others move out of the way — instead of List's insertion-line UX. Rename is
/// edit-in-place; delete reveals on hover; a context menu (Move Up/Down,
/// Delete) provides the keyboard/accessibility path.
struct ManagePresetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: PresetStore

    private static let rowHeight: CGFloat = 44

    @State private var draggedID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var proposedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.manageSavedValuesTitle).font(.appHeadline)

            Group {
                if store.presets.isEmpty {
                    Text(UIStrings.manageEmptyMessage)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(store.presets.enumerated()), id: \.element.id) { index, preset in
                                row(preset, at: index)
                            }
                        }
                    }
                    .frame(height: Self.rowHeight * CGFloat(min(max(store.presets.count, 3), 6)))
                }
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Spacer()
                Button(UIStrings.done) { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func row(_ preset: Preset, at index: Int) -> some View {
        let isDragged = draggedID == preset.id
        return PresetRow(
            store: store,
            preset: preset,
            showsDivider: index < store.presets.count - 1,
            gripper: gripperGesture(for: preset, at: index),
            moveUp: index > 0 ? { move(from: index, to: index - 1) } : nil,
            moveDown: index < store.presets.count - 1 ? { move(from: index, to: index + 1) } : nil
        )
        .frame(height: Self.rowHeight)
        .offset(y: rowOffset(index: index, isDragged: isDragged))
        .zIndex(isDragged ? 1 : 0)
        .scaleEffect(isDragged ? 1.02 : 1)
        .shadow(color: .black.opacity(isDragged ? 0.18 : 0), radius: 5, y: 2)
        .animation(isDragged ? nil : .spring(duration: 0.22), value: proposedIndex)
        .animation(.easeOut(duration: 0.12), value: draggedID)
    }

    // MARK: drag-to-reorder engine

    private func gripperGesture(for preset: Preset, at index: Int) -> some Gesture {
        // Global space: the gesture's own view moves with the pointer, so
        // local-space translation would feed back on itself and read short.
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { drag in
                draggedID = preset.id
                dragTranslation = drag.translation.height
                let raw = index + Int((dragTranslation / Self.rowHeight).rounded())
                proposedIndex = min(max(raw, 0), store.presets.count - 1)
            }
            .onEnded { _ in
                if let target = proposedIndex, target != index {
                    move(from: index, to: target)
                }
                draggedID = nil
                dragTranslation = 0
                proposedIndex = nil
            }
    }

    private func rowOffset(index: Int, isDragged: Bool) -> CGFloat {
        if isDragged { return dragTranslation }
        guard let dragged = draggedID,
              let dIdx = store.presets.firstIndex(where: { $0.id == dragged }),
              let target = proposedIndex else { return 0 }
        if dIdx < target, index > dIdx, index <= target { return -Self.rowHeight }
        if dIdx > target, index >= target, index < dIdx { return Self.rowHeight }
        return 0
    }

    private func move(from source: Int, to target: Int) {
        store.move(fromOffsets: IndexSet(integer: source),
                   toOffset: target > source ? target + 1 : target)
    }
}

private struct PresetRow<G: Gesture>: View {
    let store: PresetStore
    let preset: Preset
    let showsDivider: Bool
    let gripper: G
    let moveUp: (() -> Void)?
    let moveDown: (() -> Void)?

    @State private var editedName: String
    @State private var isHovering = false

    init(store: PresetStore, preset: Preset, showsDivider: Bool,
         gripper: G, moveUp: (() -> Void)?, moveDown: (() -> Void)?) {
        self.store = store
        self.preset = preset
        self.showsDivider = showsDivider
        self.gripper = gripper
        self.moveUp = moveUp
        self.moveDown = moveDown
        _editedName = State(initialValue: preset.name)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 20, height: 32)
                .contentShape(Rectangle())
                .gesture(gripper)
                .accessibilityHidden(true)

            Image(systemName: modeSymbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                TextField("", text: $editedName)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        do { try store.rename(id: preset.id, to: editedName.trimmingCharacters(in: .whitespaces)) }
                        catch { editedName = preset.name }   // revert to what's stored
                    }
                    .accessibilityLabel(Text(UIStrings.presetNameField))
                Text(detail)
                    .font(detailIsCode ? .caption.monospaced() : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering {
                Button(role: .destructive) { try? store.delete(id: preset.id) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(UIStrings.delete)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(alignment: .bottom) {
            if showsDivider { Divider().padding(.leading, 38) }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            if let moveUp { Button(UIStrings.moveUp, action: moveUp) }
            if let moveDown { Button(UIStrings.moveDown, action: moveDown) }
            Divider()
            Button(UIStrings.delete, role: .destructive) { try? store.delete(id: preset.id) }
        }
    }

    private var modeSymbol: String {
        switch preset.payload {
        case .basic: "envelope"
        case .advanced: "chevron.left.forwardslash.chevron.right"
        }
    }

    private var detail: String {
        switch preset.payload {
        case .basic(let fields): fields.email
        case .advanced(let html): html
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        }
    }

    private var detailIsCode: Bool {
        if case .advanced = preset.payload { return true }
        return false
    }
}
