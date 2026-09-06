import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: HotKeyController

    var body: some View {
        Form {
            Section {
                LabeledContent("Quick capture") {
                    HotKeyRecorder(combo: controller.combo) { controller.record($0) }
                        .frame(width: 160, height: 24)
                }
                Text("Click the field, then press the keys you want. Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = controller.statusMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .navigationTitle("Totogotchi Settings")
    }
}
