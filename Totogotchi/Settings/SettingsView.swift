import SwiftUI

struct SettingsView: View {
    @ObservedObject var hotKeys: HotKeyController
    @ObservedObject var notifications: NotificationsController

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
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .navigationTitle("Totogotchi Settings")
        .task { await notifications.refreshStatus() }
    }
}
