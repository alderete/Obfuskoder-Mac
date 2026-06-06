import SwiftUI
import Observation
import ObfuskoderKit

enum ResultState: Equatable {
    case empty
    case snippet(Snippet)
    case failure
}

@MainActor
@Observable
final class AppModel {
    var form = FormState()
    var showDecodedSource = false
    private(set) var result: ResultState = .empty

    var debounceSeconds: Double = AppConfig.defaultDebounceSeconds
    var fallbackMessage: String = AppConfig.defaultFallbackMessage

    private var encodeTask: Task<Void, Never>?

    /// Call whenever the form, debounce, or fallback changes.
    func scheduleEncode() {
        encodeTask?.cancel()
        guard let input = form.canonicalInput else {
            result = .empty
            return
        }
        let email = form.emailForSelfCheck
        let fallback = fallbackMessage
        let delay = debounceSeconds

        encodeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            let engine = ObfuskodeEngine(fallbackMessage: fallback)
            let outcome: ResultState
            do {
                let snippet = try await Task.detached(priority: .userInitiated) {
                    try engine.encode(input, email: email)
                }.value
                outcome = .snippet(snippet)
            } catch {
                outcome = .failure
            }
            if Task.isCancelled { return }
            self?.result = outcome
        }
    }

    var snippetText: String? {
        if case .snippet(let s) = result { return s.html }
        return nil
    }

    var decodedSource: String? {
        if case .snippet(let s) = result { return s.decodedSource }
        return nil
    }

    func clearActiveForm(undoManager: UndoManager?) {
        guard !form.activeIsEmpty else { return }
        let previous = form
        form.clearActive()
        scheduleEncode()
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreForm(previous, undoManager: undoManager)
        }
        undoManager?.setActionName(UIStrings.clearForm)
    }

    func restoreForm(_ snapshot: FormState, undoManager: UndoManager?) {
        let current = form
        form = snapshot
        scheduleEncode()
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreForm(current, undoManager: undoManager)
        }
        undoManager?.setActionName(UIStrings.clearForm)
    }

    func apply(_ preset: Preset) {
        form.apply(preset)
        scheduleEncode()
    }
}
