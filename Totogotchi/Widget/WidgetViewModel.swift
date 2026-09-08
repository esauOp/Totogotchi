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
    @Published private(set) var petState: PetState
    /// A short-lived mood that overrides the computed one, used for the cheer
    /// when a task is completed.
    @Published private(set) var reaction: PetMood?
    /// The week whose summary card is on screen, if any.
    @Published private(set) var summaryWeek: ISOWeek?
    /// False while the widget is covered, hidden, or on another Space. The pet
    /// holds still rather than burning frames nobody can see.
    @Published var isPetAnimating = true
    /// True for a few seconds after something happened worth reacting to.
    ///
    /// The pet does not loop an idle: continuous motion in the floating panel
    /// costs about 5% CPU whatever is animated, which the idle budget cannot
    /// absorb. It stirs on a mood change, on a completion and while capture is
    /// open, then settles.
    @Published private(set) var isPetStirring = false
    /// True while the capture field is open, which leans the pet towards it.
    @Published var isCapturing = false
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

    /// How long the cheer plays before the pet returns to its computed mood.
    static let reactionDuration: TimeInterval = 1.5

    private let store: TaskStore
    private let settings: AppSettings
    private let usage: UsageLog
    private let counters: WeeklyStatsRepository
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "widget")
    private var observation: TaskStoreObservation?
    private var tick: Timer?
    private var undoTimer: Timer?
    private var reactionTimer: Timer?
    private var stirTimer: Timer?

    init(
        store: TaskStore,
        settings: AppSettings,
        usage: UsageLog,
        counters: WeeklyStatsRepository
    ) {
        self.store = store
        self.settings = settings
        self.usage = usage
        self.counters = counters
        let emptyWeek = WeekView(week: ISOWeek(year: 0, week: 0), overdue: [], thisWeek: [], completed: [])
        weekView = (try? store.weekView()) ?? emptyWeek
        petState = (try? store.petState())
            ?? MoodEngine.evaluate(weekView: emptyWeek, streakDays: 0)
        observation = store.observeChanges { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        updateSummaryCard()
    }

    deinit {
        tick?.invalidate()
        undoTimer?.invalidate()
        reactionTimer?.invalidate()
        stirTimer?.invalidate()
    }

    /// The mood actually on screen: the cheer while it lasts, otherwise the
    /// mood the engine computed.
    var displayedMood: PetMood { reaction ?? petState.mood }

    // MARK: - Refreshing

    func refresh() {
        let started = CFAbsoluteTimeGetCurrent()
        do {
            weekView = try store.weekView()
            let previousMood = petState.mood
            petState = try store.petState()
            if petState.mood != previousMood {
                stirPet()
                usage.record(.moodChanged, previousMood: previousMood, newMood: petState.mood)
            }
            updateSummaryCard()
            let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1_000
            log.info("Week view and mood rebuilt in \(elapsed, format: .fixed(precision: 2)) ms; mood \(self.petState.mood.rawValue, privacy: .public)")
        } catch {
            log.error("Could not build the week view: \(String(describing: error), privacy: .public)")
        }
    }

    /// Run on every tick, after the refresh. The reminder check rides here so
    /// there is only ever one timer.
    var onTick: (() -> Void)?

    /// Starts the one-minute tick. Called whenever the widget is on screen,
    /// collapsed or expanded, because the pet and its overdue badge both go
    /// stale otherwise.
    ///
    /// Driven by `WidgetPanelController`, never by a view's `onAppear`. Swapping
    /// the panel's content view fires the old view's `onDisappear` and the new
    /// one's `onAppear` in an order SwiftUI does not promise, and a stop that
    /// landed after the matching start left the widget frozen.
    func startClock() {
        guard tick == nil else { return }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
                self?.onTick?()
            }
        }
        // The common run loop mode keeps it firing while a menu or a resize is
        // tracking, so the list cannot go stale mid-interaction.
        RunLoop.main.add(timer, forMode: .common)
        tick = timer
        log.info("Clock started")
        refresh()
    }

    /// Stops the tick while nothing is on screen to update.
    func stopClock() {
        guard tick != nil else { return }
        tick?.invalidate()
        tick = nil
        log.info("Clock stopped")
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
                usage.record(.taskCompleted, taskID: task.id)
                cheer()
            }
            let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1_000
            log.info("Toggled completion in \(elapsed, format: .fixed(precision: 1)) ms")
        } catch {
            log.error("Could not change completion: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Pet

    /// Shows the celebrating sloth briefly, then hands the pet back to whatever
    /// the engine says. Modelled as an override so the engine stays a pure
    /// function of the data.
    private func cheer() {
        reactionTimer?.invalidate()
        reaction = .celebrating
        stirPet()
        reactionTimer = Timer.scheduledTimer(withTimeInterval: Self.reactionDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reaction = nil
                self?.reactionTimer = nil
            }
        }
    }

    /// How long the pet keeps moving after something happens.
    static let stirDuration: TimeInterval = 3.0

    /// Sets the pet moving, and arranges for it to settle again.
    private func stirPet() {
        stirTimer?.invalidate()
        isPetStirring = true
        stirTimer = Timer.scheduledTimer(withTimeInterval: Self.stirDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isPetStirring = false
                self?.stirTimer = nil
            }
        }
    }

    /// Raises the summary the first time a week is finished, or on Sunday
    /// evening, and never again that week once it has been dismissed.
    ///
    /// The two triggers are deliberately one flag: finishing early on Thursday
    /// should not mean seeing the same card again on Sunday.
    private func updateSummaryCard() {
        let week = weekView.week
        guard settings.summaryDismissedWeek != week else {
            summaryWeek = nil
            return
        }
        if petState.mood == .celebrating || isSummaryHour() {
            summaryWeek = week
        }
    }

    /// True from Sunday 20:00 local until the week rolls over.
    private func isSummaryHour(now: Date? = nil) -> Bool {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let moment = now ?? Date()
        let parts = calendar.dateComponents([.weekday, .hour], from: moment)
        return parts.weekday == 1 && (parts.hour ?? 0) >= 20
    }

    /// Opened by hand from the status menu, which ignores the dismissal.
    func showSummary() {
        summaryWeek = weekView.week
    }

    func dismissSummary() {
        settings.summaryDismissedWeek = weekView.week
        summaryWeek = nil
    }

    /// After Sunday evening the button reads as moving on rather than hiding.
    var canStartNextWeek: Bool { isSummaryHour() }

    func completeSelection() {
        guard let selection, let task = task(for: selection) else { return }
        toggleCompletion(task)
    }

    // MARK: - Rescheduling

    /// The row currently showing its date picker, if any.
    @Published var reschedulingID: UUID?

    /// Moves a task's due date, and counts it against the week it left when the
    /// move pushes unfinished work into a later week.
    func reschedule(_ task: TaskItem, to newDueDate: Date) {
        do {
            let result = try store.reschedule(task.id, to: newDueDate)
            if let from = result.deferredFrom {
                try store.recordSlip(.deferred, inWeekOf: from, counters: counters)
                usage.record(.taskDeferred, taskID: task.id)
                log.info("Task deferred out of its week")
            }
            reschedulingID = nil
        } catch {
            log.error("Could not reschedule: \(String(describing: error), privacy: .public)")
        }
    }

    /// The week's numbers, for the summary card.
    func weeklyStats() -> WeeklyStats {
        (try? store.weeklyStats(counters: counters))
            ?? WeeklyStats(week: weekView.week)
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
            usage.record(.taskDeleted, taskID: task.id)
            if !task.isCompleted {
                try store.recordSlip(.deleted, inWeekOf: task.dueDate, counters: counters)
            }
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
