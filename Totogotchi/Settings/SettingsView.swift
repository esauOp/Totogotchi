import SwiftUI

struct SettingsView: View {
    @ObservedObject var hotKeys: HotKeyController
    @ObservedObject var notifications: NotificationsController
    @ObservedObject var transfer: DataTransferController
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    var body: some View {
        Form {
            Section("Quick capture") {
                LabeledContent("Shortcut") {
                    HotKeyRecorder(combo: hotKeys.combo) { hotKeys.record($0) }
                        .frame(width: 160, height: 24)
                }
                Text("Click the field, then press the keys you want. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = hotKeys.statusMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Reminders") {
                Toggle("Notify me when a task is due", isOn: $notifications.isEnabled)

                if let warning = notifications.systemWarning {
                    Label(warning, systemImage: "bell.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if notifications.systemStatus == .denied {
                    Button("Open System Settings") {
                        notifications.openSystemNotificationSettings()
                    }
                    .font(.caption)
                }
            }

            Section("Startup") {
                Toggle(
                    "Start Totogotchi at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                .accessibilityHint("Keeps the widget and reminders present after the Mac restarts")

                if let message = launchAtLogin.statusMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Your data") {
                HStack(spacing: 10) {
                    Button("Export\u{2026}") { transfer.export() }
                        .accessibilityHint("Writes your tasks, weekly statistics and usage history to a JSON file")
                    Button("Import\u{2026}") { transfer.importData() }
                        .accessibilityHint("Reads a file Totogotchi exported earlier, merging it into your tasks")
                }

                Text("Everything stays on this Mac. An import merges into what you already have rather than replacing it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let result = transfer.result {
                    Label(
                        result.message,
                        systemImage: result.isFailure ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(result.isFailure ? Color.orange : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .navigationTitle("Totogotchi Settings")
        .task {
            await notifications.refreshStatus()
            launchAtLogin.refresh()
        }
    }
}
