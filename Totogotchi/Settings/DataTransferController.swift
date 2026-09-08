import AppKit
import Combine
import TotogotchiCore
import os

/// Takes the user's data out of the app, and puts it back.
///
/// The archive code itself lives in `TotogotchiCore` and was written and tested
/// two changes ago; this exists because nothing in the app ever called it.
///
/// Both operations go through the standard panels. That is not a UI preference:
/// choosing a file through `NSSavePanel` or `NSOpenPanel` is how a sandboxed app
/// is granted access to something outside its container, and a typed path would
/// simply be denied.
@MainActor
final class DataTransferController: ObservableObject {
    /// What happened last, shown under the buttons.
    @Published private(set) var result: Result?

    enum Result: Equatable {
        case exported(fileName: String)
        case imported(taskCount: Int)
        case failed(String)

        var isFailure: Bool {
            if case .failed = self { return true }
            return false
        }

        var message: String {
            switch self {
            case let .exported(fileName):
                return "Exported to \(fileName)."
            case let .imported(taskCount):
                return taskCount == 1 ? "Imported 1 task." : "Imported \(taskCount) tasks."
            case let .failed(reason):
                return reason
            }
        }
    }

    private let store: TaskStore
    private let usage: UsageLog
    private let counters: WeeklyStatsRepository
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "transfer")

    init(store: TaskStore, usage: UsageLog, counters: WeeklyStatsRepository) {
        self.store = store
        self.usage = usage
        self.counters = counters
    }

    // MARK: - Export

    func export() {
        let panel = NSSavePanel()
        panel.title = "Export Totogotchi Data"
        panel.allowedContentTypes = [.json]
        // A backup's first companion is a second backup, so the date is in the
        // name by default.
        panel.nameFieldStringValue = "Totogotchi-\(Self.dateStamp()).json"
        panel.canCreateDirectories = true

        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else {
            // Cancelling is neither success nor failure; saying nothing is right.
            log.info("Export cancelled")
            return
        }

        do {
            try store.exportArchive(to: url, usage: usage, counters: counters)
            result = .exported(fileName: url.lastPathComponent)
            log.info("Exported data")
        } catch {
            result = .failed("Could not export: \(error.localizedDescription)")
            log.error("Export failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Import

    func importData() {
        let panel = NSOpenPanel()
        panel.title = "Import Totogotchi Data"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else {
            log.info("Import cancelled")
            return
        }

        do {
            let count = try store.importArchive(from: url, counters: counters)
            result = .imported(taskCount: count)
            log.info("Imported \(count) tasks")
        } catch let error as TaskArchiveError {
            result = .failed(error.description)
            log.error("Import refused: \(error.description, privacy: .public)")
        } catch {
            result = .failed("That file could not be read as a Totogotchi export.")
            log.error("Import failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
