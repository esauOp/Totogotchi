import SwiftUI
import TotogotchiCore

struct CaptureFieldView: View {
    @ObservedObject var model: CaptureModel
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("What needs doing?", text: $model.text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isFieldFocused)
                .onSubmit { model.submit() }
                .onChange(of: model.text) { _, _ in model.textChanged() }
                .accessibilityLabel("New task title")

            if let hint = model.hint {
                Label(hint, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Problem: \(hint)")
            } else if let preview = model.preview {
                tokenPreview(preview)
            } else if let created = model.lastCreatedTitle {
                Label("Added \(created)", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Return to add, Esc to close")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(width: 360, alignment: .leading)
        .onAppear { isFieldFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .captureFieldShouldFocus)) { _ in
            isFieldFocused = true
        }
    }

    /// Shows what the tokens typed so far will apply, so a mistyped `@fir`
    /// is obvious before Enter rather than after.
    private func tokenPreview(_ preview: ParsedCapture) -> some View {
        HStack(spacing: 6) {
            if let priority = preview.priority {
                Label(priority.rawValue.capitalized, systemImage: "flag.fill")
                    .foregroundStyle(.tint)
            }
            if let dueDate = preview.dueDate {
                Label(
                    dueDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)),
                    systemImage: "calendar"
                )
                .foregroundStyle(.tint)
            }
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(previewLabel(preview))
    }

    private func previewLabel(_ preview: ParsedCapture) -> String {
        var parts: [String] = []
        if let priority = preview.priority { parts.append("\(priority.rawValue) priority") }
        if let dueDate = preview.dueDate {
            parts.append("due \(dueDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
        }
        return "Will be created with " + parts.joined(separator: ", ")
    }
}

extension Notification.Name {
    static let captureFieldShouldFocus = Notification.Name("CaptureFieldShouldFocus")
}
