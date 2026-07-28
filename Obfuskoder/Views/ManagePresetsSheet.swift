import SwiftUI
import AppKit
import ObfuskoderKit

/// Manage Saved Values panel (MAC-1/MAC-2). Rows carry a gripper that drags
/// with live, animated reordering — the lifted row follows the pointer and the
/// others move out of the way — instead of List's insertion-line UX. Rename is
/// edit-in-place; delete reveals on hover; a context menu (Move Up/Down,
/// Delete) provides the keyboard/accessibility path.
struct ManagePresetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UndoRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var store: PresetStore
    /// Per-session undo stack for delete/reorder, registered with the router
    /// while this panel is open. Rename stays on native field undo.
    @State private var undo: SavedValuesUndo

    init(store: PresetStore) {
        _store = Bindable(wrappedValue: store)
        _undo = State(initialValue: SavedValuesUndo(store: store))
    }

    private static let rowHeight: CGFloat = 44
    /// Fixed list viewport = 3.5 rows, so the panel never resizes as items are
    /// added/removed (the list scrolls inside); the half row hints at more.
    private static let listHeight: CGFloat = rowHeight * 3.5

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
                        .frame(maxWidth: .infinity, minHeight: Self.listHeight)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(store.presets.enumerated()), id: \.element.id) { index, preset in
                                row(preset, at: index)
                            }
                        }
                        // Animate add/remove (delete + undo-restore) so a
                        // restored row squeezes into its space and the rows below
                        // make room. Keyed to `count`, not the id-list, so reorder
                        // (count unchanged) keeps using the row drag animations.
                        .animation(reduceMotion ? nil : .default, value: store.presets.count)
                    }
                    .frame(height: Self.listHeight)
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
        .onAppear { router.savedValuesUndo = undo }
        .onDisappear { router.savedValuesUndo = nil; undo.reset() }
    }

    private func row(_ preset: Preset, at index: Int) -> some View {
        let isDragged = draggedID == preset.id
        return PresetRow(
            store: store,
            preset: preset,
            showsDivider: index < store.presets.count - 1,
            gripper: gripperGesture(for: preset, at: index),
            moveUp: index > 0 ? { move(from: index, to: index - 1) } : nil,
            moveDown: index < store.presets.count - 1 ? { move(from: index, to: index + 1) } : nil,
            delete: { deletePreset(preset) }
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
        let name = store.presets[source].name
        undo.move(fromOffsets: IndexSet(integer: source),
                  toOffset: target > source ? target + 1 : target,
                  actionName: UIStrings.savedValueMoveAction(name: name))
    }

    private func deletePreset(_ preset: Preset) {
        do { try undo.delete(id: preset.id, actionName: UIStrings.savedValueDeleteAction(name: preset.name)) }
        catch { NSSound.beep() }
    }
}

private struct PresetRow<G: Gesture>: View {
    let store: PresetStore
    let preset: Preset
    let showsDivider: Bool
    let gripper: G
    let moveUp: (() -> Void)?
    let moveDown: (() -> Void)?
    let delete: () -> Void

    @State private var editedName: String
    @State private var isHovering = false
    @FocusState private var nameFocused: Bool

    init(store: PresetStore, preset: Preset, showsDivider: Bool,
         gripper: G, moveUp: (() -> Void)?, moveDown: (() -> Void)?,
         delete: @escaping () -> Void) {
        self.store = store
        self.preset = preset
        self.showsDivider = showsDivider
        self.gripper = gripper
        self.moveUp = moveUp
        self.moveDown = moveDown
        self.delete = delete
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
                    .focused($nameFocused)
                    .onSubmit { commitRename() }
                    // Commit (or revert) when focus leaves the field too, so a
                    // click-away doesn't leave the row and the store disagreeing.
                    .onChange(of: nameFocused) { if !nameFocused { commitRename() } }
                    // Clicking Done dismisses without reliably blurring the
                    // field, so onChange above may not fire; committing on
                    // disappear saves a pending rename when the sheet closes.
                    .onDisappear { commitRename() }
                    .accessibilityLabel(Text(UIStrings.presetNameField))
                Text(detail)
                    .font(detailIsCode ? .caption.monospaced() : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering {
                Button(role: .destructive) { delete() } label: {
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
            Button(UIStrings.delete, role: .destructive) { delete() }
        }
    }

    /// Rename to the edited text, reverting on an empty name and beeping (and
    /// reverting) if the store rejects it — never silently drop the edit.
    private func commitRename() {
        // Skip if the row's preset is gone (e.g. deleted while a rename was
        // pending) so the disappear-commit can't beep about a missing id.
        guard store.presets.contains(where: { $0.id == preset.id }) else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard trimmed != preset.name else { return }
        guard !trimmed.isEmpty else { editedName = preset.name; return }
        do { try store.rename(id: preset.id, to: trimmed) }
        catch { NSSound.beep(); editedName = preset.name }
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
