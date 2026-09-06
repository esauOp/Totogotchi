import Foundation
import TotogotchiCore
import os

/// Drives the quick-capture field: what is typed, what is wrong with it, and
/// what happens on Enter.
@MainActor
final class CaptureModel: ObservableObject {
    @Published var text = ""
    @Published var hint: String?
    @Published private(set) var lastCreatedTitle: String?

    private let store: TaskStore
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "capture")

    /// Called when the field should close, for example after Esc.
    var onDismiss: (() -> Void)?

    init(store: TaskStore) {
        self.store = store
    }

    /// Creates a task from the current text.
    ///
    /// On success the field empties so the next task can be typed straight away,
    /// which is what capturing during a meeting needs. On failure the text stays
    /// put and a hint explains what to fix.
    func submit() {
        let started = CFAbsoluteTimeGetCurrent()
        do {
            let task = try store.create(title: text)
            text = ""
            hint = nil
            lastCreatedTitle = task.title
            let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1_000
            log.info("Created task in \(elapsed, format: .fixed(precision: 1)) ms")
        } catch let error as TaskValidationError {
            hint = error.description
            if case .emptyTitle = error { text = "" }
            log.info("Capture refused: \(error.description, privacy: .public)")
        } catch {
            hint = "Could not save that task."
            log.error("Capture failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Throws away what was typed and closes the field.
    func cancel() {
        text = ""
        hint = nil
        onDismiss?()
    }

    /// Clears a stale hint as soon as the user starts fixing the problem.
    func textChanged() {
        if hint != nil, !text.isEmpty { hint = nil }
    }
}
