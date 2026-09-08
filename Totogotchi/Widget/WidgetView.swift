import SwiftUI
import TotogotchiCore

struct WidgetView: View {
    @ObservedObject var model: WidgetViewModel
    let onCollapse: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.summaryWeek != nil {
                summaryCard
            } else {
                list
            }
            if let undo = model.pendingUndo {
                Divider()
                undoBar(undo)
            }
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            PetView(
                mood: model.displayedMood,
                reason: model.petState.reason,
                isAnimating: model.isPetAnimating,
                isStirring: model.isPetStirring,
                isAttentive: model.isCapturing
            )
            .frame(height: 52)

            VStack(alignment: .leading, spacing: 1) {
                Text("Totogotchi").font(.headline)
                Text(model.weekTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onCollapse) {
                Image(systemName: "chevron.up.chevron.down")
            }
            .buttonStyle(.borderless)
            .help("Collapse to the pet")
            .accessibilityLabel("Collapse widget")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - List

    private var list: some View {
        List(selection: $model.selection) {
            if !model.weekView.overdue.isEmpty {
                Section("Overdue") {
                    ForEach(model.weekView.overdue) { task in
                        TaskRowView(task: task, isOverdue: true, model: model).tag(task.id)
                    }
                }
            }

            Section("This week") {
                if model.weekView.thisWeek.isEmpty {
                    Text(model.weekView.overdue.isEmpty ? "Nothing due this week." : "Nothing else due this week.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.weekView.thisWeek) { task in
                        TaskRowView(task: task, isOverdue: false, model: model).tag(task.id)
                    }
                }
            }

            if !model.weekView.completed.isEmpty {
                Section {
                    if model.isCompletedExpanded {
                        ForEach(model.weekView.completed) { task in
                            TaskRowView(task: task, isOverdue: false, model: model).tag(task.id)
                        }
                    }
                } header: {
                    Button {
                        model.isCompletedExpanded.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: model.isCompletedExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                            Text("Completed (\(model.weekView.completedCount))")
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(model.weekView.completedCount) completed this week, \(model.isCompletedExpanded ? "expanded" : "collapsed")"
                    )
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .onKeyPress(.space) {
            guard model.editingID == nil else { return .ignored }
            model.completeSelection()
            return .handled
        }
        .onKeyPress(.return) {
            guard model.editingID == nil else { return .ignored }
            model.beginEditingSelection()
            return .handled
        }
        .onKeyPress(.delete) {
            guard model.editingID == nil else { return .ignored }
            model.deleteSelection()
            return .handled
        }
        .onKeyPress(.deleteForward) {
            guard model.editingID == nil else { return .ignored }
            model.deleteSelection()
            return .handled
        }
    }

    // MARK: - Weekly summary

    private var summaryCard: some View {
        ScrollView {
            WeeklySummaryCard(
                stats: model.weeklyStats(),
                streakDays: model.petState.streakDays,
                mood: model.displayedMood,
                reason: model.petState.reason,
                canStartNextWeek: model.canStartNextWeek,
                onDismiss: { model.dismissSummary() }
            )
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Undo

    private func undoBar(_ undo: WidgetViewModel.PendingUndo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Deleted \u{201C}\(undo.title)\u{201D}")
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("Undo") { model.undoDelete() }
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .transition(reduceMotion ? .identity : .opacity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            if model.overdueCount > 0 {
                Label("\(model.overdueCount) overdue", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .accessibilityLabel("Open settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
