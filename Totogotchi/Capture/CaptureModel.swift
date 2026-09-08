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
    /// What pressing Enter would set right now, shown beside the field so the
    /// user can see a token took effect before committing to it.
    @Published private(set) var preview: ParsedCapture?

    private let store: TaskStore
    private let usage: UsageLog
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "capture")

    /// How the field was opened, carried onto the task it creates.
    var source: TaskSource = .hotkey

    /// Called when the field should close, for example after Esc.
    var onDismiss: (() -> Void)?

    init(store: TaskStore, usage: UsageLog) {
        self.store = store
        self.usage = usage
    }

    /// Creates a task from the current text.
    ///
    /// On success the field empties so the next task can be typed straight away,
    /// which is what capturing during a meeting needs. On failure the text stays
    /// put and a hint explains what to fix.
    func submit() {
        let started = CFAbsoluteTimeGetCurrent()
        do {
            let task = try store.createFromCapture(text)
            text = ""
            hint = nil
            preview = nil
            lastCreatedTitle = task.title
            usage.record(.taskCreated, taskID: task.id, source: source)
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
        usage.record(.captureCancelled)
        onDismiss?()
    }

    /// Clears a stale hint as soon as the user starts fixing the problem, and
    /// keeps the token preview in step with what has been typed.
    func textChanged() {
        if hint != nil, !text.isEmpty { hint = nil }
        let parsed = store.parseCapture(text)
        // Nothing to show unless a token actually landed.
        preview = (parsed.priority == nil && parsed.dueDate == nil) ? nil : parsed
    }
}
