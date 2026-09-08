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
            Menu("Due") {
                Button("Today") { model.reschedule(task, to: endOfDay(offsetDays: 0)) }
                Button("Tomorrow") { model.reschedule(task, to: endOfDay(offsetDays: 1)) }
                Button("Next Week") { model.reschedule(task, to: endOfDay(offsetDays: 7)) }
                Divider()
                Button("Pick a Date\u{2026}") { model.reschedulingID = task.id }
            }
            Divider()
            Button("Delete", role: .destructive) { model.delete(task) }
        }
        .popover(
            isPresented: Binding(
                get: { model.reschedulingID == task.id },
                set: { if !$0 { model.reschedulingID = nil } }
            )
        ) {
            datePicker
        }
    }

    /// A calendar picker for the cases the quick options do not cover.
    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(
                "Due",
                selection: Binding(
                    get: { task.dueDate },
                    set: { model.reschedule(task, to: endOfDay(for: $0)) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
        .padding(12)
        .frame(width: 280)
    }

    /// Tasks fall due at the end of a day, the same convention capture tokens
    /// use, so a date chosen here means the same thing as `@fri` typed there.
    private func endOfDay(for date: Date) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        guard let interval = calendar.dateInterval(of: .day, for: date) else { return date }
        return interval.end.addingTimeInterval(-1)
    }

    private func endOfDay(offsetDays: Int) -> Date {
        endOfDay(for: Date().addingTimeInterval(Double(offsetDays) * 86_400))
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
