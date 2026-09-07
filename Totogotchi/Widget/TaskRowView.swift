import SwiftUI
import TotogotchiCore

struct TaskRowView: View {
    let task: TaskItem
    let isOverdue: Bool
    @ObservedObject var model: WidgetViewModel

    @FocusState private var isEditing: Bool

    private var isBeingEdited: Bool { model.editingID == task.id }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                model.toggleCompletion(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark not done" : "Mark done")

            if isBeingEdited {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Title", text: $model.editText)
                        .textFieldStyle(.plain)
                        .focused($isEditing)
                        .onSubmit { model.commitEdit() }
                        .onExitCommand { model.cancelEdit() }
                        .onAppear { isEditing = true }
                    if let hint = model.editHint {
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(task.title)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(2)
                    .onTapGesture(count: 2) { model.beginEditing(task) }
            }

            Spacer(minLength: 4)

            if isOverdue {
                // Icon as well as colour, so the state does not depend on
                // colour perception.
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }

            Text(dueLabel)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(isOverdue ? Color.orange : Color.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(task.isCompleted ? .isSelected : [])
        .contextMenu {
            Button(task.isCompleted ? "Mark Not Done" : "Mark Done") { model.toggleCompletion(task) }
            Button("Rename\u{2026}") { model.beginEditing(task) }
            Divider()
            Button("Delete", role: .destructive) { model.delete(task) }
        }
    }

    private var dueLabel: String {
        task.dueDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private var accessibilityLabel: String {
        var parts = [task.title, "due \(dueLabel)", "\(task.priority.rawValue) priority"]
        if isOverdue { parts.insert("overdue", at: 1) }
        if task.isCompleted { parts.append("completed") }
        return parts.joined(separator: ", ")
    }
}
