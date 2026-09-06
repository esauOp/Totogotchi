import Foundation
import Testing
import TotogotchiCore

@Suite("Persistence performance")
struct PersistencePerformanceTests {

    private let now = makeDate(2026, 9, 9, 10, 0)

    @Test("Saving a task stays under 50 ms at p95 with ten thousand tasks stored")
    func saveLatencyWithTenThousandTasks() throws {
        try withTemporaryDirectory { directory in
            let repository = try SwiftDataTaskRepository(url: directory.appendingPathComponent("Perf.store"))
            let store = TaskStore(repository: repository, week: WeekCalendar(timeZone: TZ.utc), clock: { self.now })

            let seedStart = Date()
            for task in try makeMixedTasks(count: 10_000, now: now) {
                try store.replaceForTesting(task)
            }
            let seedSeconds = Date().timeIntervalSince(seedStart)

            var samples: [Double] = []
            samples.reserveCapacity(100)
            for index in 0..<100 {
                let task = try TaskItem(
                    title: "Timed save \(index)",
                    dueDate: now,
                    createdAt: now
                )
                let start = Date()
                try store.replaceForTesting(task)
                samples.append(Date().timeIntervalSince(start) * 1_000)
            }

            let p95 = percentile95(samples)
            let median = samples.sorted()[samples.count / 2]
            print(
                """
                [perf] seeded 10,000 tasks in \(String(format: "%.1f", seedSeconds)) s; \
                save median \(String(format: "%.2f", median)) ms, \
                p95 \(String(format: "%.2f", p95)) ms, \
                max \(String(format: "%.2f", samples.max() ?? 0)) ms
                """
            )

            #expect(try repository.fetchAll().count == 10_100)
            #expect(p95 < 50)
        }
    }
}
