import Foundation

/// The on-disk shape of an export: everything needed to rebuild a store.
///
/// Version 2 added the usage log and the weekly counters. Version 1 files are
/// still read, as tasks with no history: refusing to open the format the app
/// itself wrote last month would be a poor way to treat a backup.
public struct TaskArchive: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 2
    public static let readableFormatVersions: Set<Int> = [1, 2]

    public let formatVersion: Int
    public let exportedAt: Date
    public let tasks: [TaskItem]
    public let weeklyStats: [WeeklyStats]
    public let usageEvents: [UsageEvent]

    public init(
        tasks: [TaskItem],
        weeklyStats: [WeeklyStats] = [],
        usageEvents: [UsageEvent] = [],
        exportedAt: Date,
        formatVersion: Int = TaskArchive.currentFormatVersion
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.tasks = tasks
        self.weeklyStats = weeklyStats
        self.usageEvents = usageEvents
    }

    /// Version 1 files carry no history, so those two collections are absent
    /// rather than empty and decoding has to tolerate that.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        tasks = try container.decode([TaskItem].self, forKey: .tasks)
        weeklyStats = try container.decodeIfPresent([WeeklyStats].self, forKey: .weeklyStats) ?? []
        usageEvents = try container.decodeIfPresent([UsageEvent].self, forKey: .usageEvents) ?? []
    }
}

public enum TaskArchiveError: Error, Equatable, Sendable {
    case unsupportedFormatVersion(found: Int, supported: Int)
}

extension TaskArchiveError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .unsupportedFormatVersion(found, supported):
            return "This file uses export format \(found); this version reads format \(supported)."
        }
    }
}

enum TaskArchiveCoder {
    /// ISO-8601 with fractional seconds: readable in a text editor and accurate
    /// to the millisecond, which is far finer than anything the app records.
    /// Sub-millisecond digits are lost, so a round trip lands within a
    /// millisecond of the original rather than on the identical `Double`.
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(dateFormatter.string(from: date))
        }
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = dateFormatter.date(from: text) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected an ISO-8601 date with fractional seconds, got \(text)."
                    )
                )
            }
            return date
        }
        return decoder
    }
}

extension TaskStore {
    /// Writes every task, including completed and soft-deleted ones, to `url`.
    ///
    /// The write is atomic, so a failure part-way leaves the previous file
    /// untouched and exactly one file ends up at the chosen location.
    public func exportArchive(
        to url: URL,
        usage: UsageLog? = nil,
        counters: WeeklyStatsRepository? = nil
    ) throws {
        var stats: [WeeklyStats] = []
        if let counters {
            stats = try counters.allWeeks().map {
                try weeklyStats(for: $0, counters: counters)
            }
        }
        let archive = TaskArchive(
            tasks: try allTasksForExport(),
            weeklyStats: stats,
            usageEvents: (try? usage?.allEvents()) ?? [],
            exportedAt: exportClock()
        )
        let data = try TaskArchiveCoder.makeEncoder().encode(archive)
        try data.write(to: url, options: .atomic)
    }

    /// Reads an archive and writes its tasks into the store, replacing any task
    /// that has the same identifier. Returns how many tasks were imported.
    @discardableResult
    public func importArchive(
        from url: URL,
        counters: WeeklyStatsRepository? = nil
    ) throws -> Int {
        let data = try Data(contentsOf: url)
        let archive = try TaskArchiveCoder.makeDecoder().decode(TaskArchive.self, from: data)
        guard TaskArchive.readableFormatVersions.contains(archive.formatVersion) else {
            throw TaskArchiveError.unsupportedFormatVersion(
                found: archive.formatVersion,
                supported: TaskArchive.currentFormatVersion
            )
        }
        for task in archive.tasks {
            try replace(task)
        }
        if let counters {
            for stats in archive.weeklyStats {
                try counters.setCounters(
                    deleted: stats.deleted,
                    deferred: stats.deferred,
                    for: stats.week
                )
            }
        }
        return archive.tasks.count
    }
}
