import SwiftUI
import AppKit

/// Routes the Edit-menu Undo/Redo commands to the frontmost valid editing
/// context (spec §3, ADR §3):
///
/// - Main window, no sheet: the model's per-mode form undo.
/// - A focused auxiliary editable field (Save/Manage sheet, Settings): that
///   field's NATIVE text undo. Main-form field editors set `allowsUndo = false`,
///   so they are excluded here and fall through to the model.
/// - Anything else (modal with no text focus, Help window): disabled.
///
/// `performUndo`/`performRedo` evaluate the target live, so the keyboard path is
/// always correct. Menu titles/enabled state are re-rendered via `tick`, bumped
/// on key-window changes (§2, §10.7), and via the model's own observable state.
@MainActor
@Observable
final class UndoRouter {
    private let model: AppModel
    @ObservationIgnored weak var mainWindow: NSWindow?
    private var tick = 0
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(model: AppModel) {
        self.model = model
        for name: NSNotification.Name in [NSWindow.didBecomeKeyNotification,
                                          NSWindow.didResignKeyNotification] {
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
        return isMainFormContext && model.canUndo
    }
    var canRedo: Bool {
        _ = tick
        if let um = auxTextView?.undoManager { return um.canRedo }
        return isMainFormContext && model.canRedo
    }
    var undoTitle: String {
        _ = tick
        if let um = auxTextView?.undoManager { return um.undoMenuItemTitle }
        return isMainFormContext ? model.undoTitle : String(localized: "Undo")
    }
    var redoTitle: String {
        _ = tick
        if let um = auxTextView?.undoManager { return um.redoMenuItemTitle }
        return isMainFormContext ? model.redoTitle : String(localized: "Redo")
    }

    func performUndo() {
        if let um = auxTextView?.undoManager { if um.canUndo { um.undo() }; return }
        if isMainFormContext { model.undo() }
    }
    func performRedo() {
        if let um = auxTextView?.undoManager { if um.canRedo { um.redo() }; return }
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
