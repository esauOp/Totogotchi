import Foundation

/// The on-disk shape of an export: everything needed to rebuild a store.
public struct TaskArchive: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public let formatVersion: Int
    public let exportedAt: Date
    public let tasks: [TaskItem]

    public init(tasks: [TaskItem], exportedAt: Date, formatVersion: Int = TaskArchive.currentFormatVersion) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.tasks = tasks
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
    public func exportArchive(to url: URL) throws {
        let archive = TaskArchive(tasks: try allTasksForExport(), exportedAt: exportClock())
        let data = try TaskArchiveCoder.makeEncoder().encode(archive)
        try data.write(to: url, options: .atomic)
    }

    /// Reads an archive and writes its tasks into the store, replacing any task
    /// that has the same identifier. Returns how many tasks were imported.
    @discardableResult
    public func importArchive(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let archive = try TaskArchiveCoder.makeDecoder().decode(TaskArchive.self, from: data)
        guard archive.formatVersion == TaskArchive.currentFormatVersion else {
            throw TaskArchiveError.unsupportedFormatVersion(
                found: archive.formatVersion,
                supported: TaskArchive.currentFormatVersion
            )
        }
        for task in archive.tasks {
            try replace(task)
        }
        return archive.tasks.count
    }
}
