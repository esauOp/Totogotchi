import Foundation
import TotogotchiCore
import os

/// What the widget shows and what its controls do.
///
/// Recomputes from two sources: the store telling it something changed, and a
/// one-minute tick for the two things that change on their own, a task becoming
/// overdue and the week rolling over.
@MainActor
final class WidgetViewModel: ObservableObject {
    /// How long the Undo control stays available after a delete.
    static let undoWindow: TimeInterval = TaskStore.undoWindow

    @Published private(set) var weekView: WeekView
    @Published var selection: UUID?
    @Published private(set) var editingID: UUID?
    @Published var editText: String = ""
    @Published private(set) var editHint: String?
    @Published private(set) var pendingUndo: PendingUndo?
    @Published var isCompletedExpanded = false

    struct PendingUndo: Equatable {
        let id: UUID
        let title: String
    }

    private let store: TaskStore
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "widget")
    private var observation: TaskStoreObservation?
    private var tick: Timer?
    private var undoTimer: Timer?

    init(store: TaskStore) {
        self.store = store
        weekView = (try? store.weekView()) ?? WeekView(week: ISOWeek(year: 0, week: 0), overdue: [], thisWeek: [], completed: [])
        observation = store.observeChanges { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    deinit {
        tick?.invalidate()
        undoTimer?.invalidate()
    }

    // MARK: - Refreshing

    func refresh() {
        let started = CFAbsoluteTimeGetCurrent()
        do {
            weekView = try store.weekView()
            let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1_000
            log.info("Week view rebuilt in \(elapsed, format: .fixed(precision: 2)) ms for \(self.weekView.openCount + self.weekView.completedCount) tasks")
        } catch {
            log.error("Could not build the week view: \(String(describing: error), privacy: .public)")
        }
    }

    /// Starts the one-minute tick. Called when the widget begins showing a list.
    func startClock() {
        guard tick == nil else { return }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // The common run loop mode keeps it firing while a menu or a resize is
        // tracking, so the list cannot go stale mid-interaction.
        RunLoop.main.add(timer, forMode: .common)
        tick = timer
        refresh()
    }

    /// Stops the tick while nothing is on screen to update.
    func stopClock() {
        tick?.invalidate()
        tick = nil
    }

    // MARK: - Derived text

    var weekTitle: String {
        let done = weekView.completedCount
        let total = done + weekView.openCount
        guard total > 0 else { return "Week \(weekView.week.week) · nothing due" }
        return "Week \(weekView.week.week) · \(done) of \(total) done"
    }

    var overdueCount: Int { weekView.overdueCount }

    // MARK: - Actions

    func toggleCompletion(_ task: TaskItem) {
        let started = CFAbsoluteTimeGetCurrent()
        do {
            if task.isCompleted {
                _ = try store.uncomplete(task.id)
            } else {
                _ = try store.complete(task.id)
            }
            let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1_000
            log.info("Toggled completion in \(elapsed, format: .fixed(precision: 1)) ms")
        } catch {
            log.error("Could not change completion: \(String(describing: error), privacy: .public)")
        }
    }

    func completeSelection() {
        guard let selection, let task = task(for: selection) else { return }
        toggleCompletion(task)
    }

    // MARK: - Editing

    func beginEditing(_ task: TaskItem) {
        editingID = task.id
        editText = task.title
        editHint = nil
    }

    func beginEditingSelection() {
        guard let selection, let task = task(for: selection) else { return }
        beginEditing(task)
    }

    func commitEdit() {
        guard let editingID else { return }
        do {
            _ = try store.rename(editingID, to: editText)
            self.editingID = nil
            editHint = nil
        } catch let error as TaskValidationError {
            editHint = error.description
        } catch {
            editHint = "Could not save that title."
        }
    }

    func cancelEdit() {
        editingID = nil
        editHint = nil
    }

    // MARK: - Deleting

    func delete(_ task: TaskItem) {
        // A second delete while the bar is up commits the first: the widget
        // offers one Undo, not a stack of them.
        finishUndoWindow()
        do {
            try store.delete(task.id)
            pendingUndo = PendingUndo(id: task.id, title: task.title)
            if selection == task.id { selection = nil }
            undoTimer = Timer.scheduledTimer(withTimeInterval: Self.undoWindow, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.finishUndoWindow() }
            }
        } catch {
            log.error("Could not delete: \(String(describing: error), privacy: .public)")
        }
    }

    func deleteSelection() {
        guard let selection, let task = task(for: selection) else { return }
        delete(task)
    }

    func undoDelete() {
        guard let pendingUndo else { return }
        do {
            _ = try store.undoDelete(pendingUndo.id)
            selection = pendingUndo.id
        } catch {
            log.error("Could not undo the delete: \(String(describing: error), privacy: .public)")
        }
        finishUndoWindow()
    }

    private func finishUndoWindow() {
        undoTimer?.invalidate()
        undoTimer = nil
        pendingUndo = nil
    }

    // MARK: - Lookup

    func task(for id: UUID) -> TaskItem? {
        weekView.overdue.first { $0.id == id }
            ?? weekView.thisWeek.first { $0.id == id }
            ?? weekView.completed.first { $0.id == id }
    }

    /// The rows the arrow keys move through, in the order they are drawn.
    var navigableTasks: [TaskItem] {
        weekView.overdue + weekView.thisWeek + (isCompletedExpanded ? weekView.completed : [])
    }
}
