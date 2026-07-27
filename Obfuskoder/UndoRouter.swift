import SwiftUI
import AppKit
import ObfuskoderKit

/// Routes the Edit-menu Undo/Redo commands to the frontmost valid editing
/// context (spec §3, ADR §3):
///
/// - A focused auxiliary editable field (Save/Manage sheet, Settings): that
///   field's NATIVE text undo. Main-form field editors set `allowsUndo = false`,
///   so they are excluded here and fall through.
/// - The Manage Saved Values panel (when open and no field focused): its
///   per-session saved-values undo stack (delete/reorder), set on `savedValuesUndo`.
/// - Main window, no sheet: the model's per-mode form undo.
/// - Anything else (modal with no text focus, Help window): disabled.
///
/// `performUndo`/`performRedo` evaluate the target live, so the keyboard path is
/// always correct. Menu titles/enabled state are re-rendered via `tick`, bumped
/// on key-window changes (§2, §10.7), auxiliary/undo-manager notifications, and
/// via the model's own observable state.
@MainActor
@Observable
final class UndoRouter {
    private let model: AppModel
    @ObservationIgnored weak var mainWindow: NSWindow?
    /// The Manage Saved Values panel's per-session undo stack, set while that
    /// panel is open (cleared on close). Non-nil ⇒ the panel is the active
    /// context, so ⌘Z targets delete/reorder undo (unless a name field is
    /// focused, where native text undo wins).
    @ObservationIgnored weak var savedValuesUndo: SavedValuesUndo?
    private var tick = 0
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(model: AppModel) {
        self.model = model
        // Refresh the menu on context changes that carry no observable signal:
        // key-window switches (sheets, Settings/Help), field-focus switches
        // within a window, edits inside an AUXILIARY field (whose native undo
        // state lives on the field editor's own manager), and undo/redo activity
        // on any UndoManager (covers the saved-values stack, whose canUndo/title
        // are not on the observable model). The main-form path refreshes via
        // `model` and is unaffected by the extra ticks.
        let names: [NSNotification.Name] = [
            NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
            NSControl.textDidBeginEditingNotification, NSControl.textDidEndEditingNotification,
            NSControl.textDidChangeNotification,
            NSText.didBeginEditingNotification, NSText.didEndEditingNotification,
            NSText.didChangeNotification,
            .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange,
            .NSUndoManagerDidCloseUndoGroup,
        ]
        for name in names {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick &+= 1 }
            })
        }
    }

    /// A focused auxiliary text view whose native undo is live. Main-form field
    /// editors (allowsUndo == false) are excluded.
    private var auxTextView: NSTextView? {
        guard let tv = NSApp.keyWindow?.firstResponder as? NSTextView, tv.allowsUndo else { return nil }
        return tv
    }

    private var isMainFormContext: Bool {
        guard let key = NSApp.keyWindow, key == mainWindow, mainWindow?.attachedSheet == nil else { return false }
        return true
    }

    var canUndo: Bool {
        _ = tick
        if let um = auxTextView?.undoManager { return um.canUndo }
        if let sv = savedValuesUndo { return sv.canUndo }
        return isMainFormContext && model.canUndo
    }
    var canRedo: Bool {
        _ = tick
        if let um = auxTextView?.undoManager { return um.canRedo }
        if let sv = savedValuesUndo { return sv.canRedo }
        return isMainFormContext && model.canRedo
    }
    var undoTitle: String {
        _ = tick
        if let um = auxTextView?.undoManager { return um.undoMenuItemTitle }
        if let sv = savedValuesUndo { return sv.undoMenuItemTitle }
        return isMainFormContext ? model.undoTitle : String(localized: "Undo")
    }
    var redoTitle: String {
        _ = tick
        if let um = auxTextView?.undoManager { return um.redoMenuItemTitle }
        if let sv = savedValuesUndo { return sv.redoMenuItemTitle }
        return isMainFormContext ? model.redoTitle : String(localized: "Redo")
    }

    func performUndo() {
        if let um = auxTextView?.undoManager { if um.canUndo { um.undo() }; return }
        if let sv = savedValuesUndo { sv.undo(); return }
        if isMainFormContext { model.undo() }
    }
    func performRedo() {
        if let um = auxTextView?.undoManager { if um.canRedo { um.redo() }; return }
        if let sv = savedValuesUndo { sv.redo(); return }
        if isMainFormContext { model.redo() }
    }
}

/// Captures the hosting `NSWindow` so the router can identify the main window.
struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in onResolve(view?.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
