import SwiftUI

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
}

extension Notification.Name {
    static let captureFieldShouldFocus = Notification.Name("CaptureFieldShouldFocus")
}
