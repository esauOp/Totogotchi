import Foundation
import TotogotchiCore

enum TZ {
    static let utc = TimeZone(identifier: "UTC")!
    static let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
}

/// Builds a date from wall-clock components in a given time zone.
func makeDate(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
    in timeZone: TimeZone = TZ.utc
) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    guard let date = calendar.date(from: components) else {
        preconditionFailure("Invalid date components")
    }
    return date
}

/// Wall-clock parts of a date in a given time zone, for assertions.
func parts(of date: Date, in timeZone: TimeZone) -> DateComponents {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second, .weekday],
        from: date
    )
}

/// Gregorian weekday numbers, where Sunday is 1.
enum Weekday {
    static let sunday = 1
    static let monday = 2
}

/// A clock the tests move by hand.
final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    /// Captures the clock strongly: the store outlives the tuple element in
    /// tests that ignore the clock, and an unowned capture would dangle.
    var read: () -> Date { { self.now } }
    func advance(by interval: TimeInterval) { now += interval }
}

/// A store wired to an in-memory repository and a controllable clock.
func makeStore(now: Date) -> (store: TaskStore, clock: TestClock, repository: InMemoryTaskRepository) {
    let clock = TestClock(now)
    let repository = InMemoryTaskRepository()
    let store = TaskStore(
        repository: repository,
        week: WeekCalendar(timeZone: TZ.utc),
        clock: clock.read
    )
    return (store, clock, repository)
}

/// Runs `body` with a fresh temporary directory that is removed afterwards.
func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("totogotchi-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    return try body(directory)
}

/// A spread of tasks covering every priority, completed, open and deleted states.
func makeMixedTasks(count: Int, now: Date) throws -> [TaskItem] {
    let priorities = Priority.allCases
    return try (0..<count).map { index in
        var task = try TaskItem(
            title: "Task \(index)",
            notes: index.isMultiple(of: 3) ? "Note \(index)" : nil,
            priority: priorities[index % priorities.count],
            dueDate: now.addingTimeInterval(Double(index) * 3_600),
            createdAt: now.addingTimeInterval(Double(-index)),
            recurrence: index.isMultiple(of: 5) ? .weekly : Recurrence.none
        )
        if index.isMultiple(of: 4) {
            task.markCompleted(at: now.addingTimeInterval(Double(index)), now: now.addingTimeInterval(1_000_000))
        }
        if index.isMultiple(of: 7) {
            task.markDeleted(at: now.addingTimeInterval(Double(index) * 2))
        }
        return task
    }
}

/// The value at the 95th percentile of `samples`.
func percentile95(_ samples: [Double]) -> Double {
    precondition(!samples.isEmpty)
    let sorted = samples.sorted()
    let index = Int((Double(sorted.count - 1) * 0.95).rounded(.up))
    return sorted[index]
}
