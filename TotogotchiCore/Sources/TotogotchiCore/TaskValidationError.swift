import Foundation

/// Why a task could not be created or edited.
public enum TaskValidationError: Error, Equatable, Sendable {
    /// The title was empty or contained only whitespace.
    case emptyTitle
    /// The title exceeded the maximum length.
    case titleTooLong(maxLength: Int, actualLength: Int)
}

extension TaskValidationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .emptyTitle:
            return "A task needs a title."
        case let .titleTooLong(maxLength, actualLength):
            return "A title can be at most \(maxLength) characters; this one is \(actualLength)."
        }
    }
}

/// Rules for a task title: trimmed, non-empty, at most 200 characters.
public enum TaskTitle {
    public static let maxLength = 200

    /// Returns the trimmed title, or throws when it is empty or too long.
    public static func validated(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TaskValidationError.emptyTitle }
        guard trimmed.count <= maxLength else {
            throw TaskValidationError.titleTooLong(maxLength: maxLength, actualLength: trimmed.count)
        }
        return trimmed
    }
}
