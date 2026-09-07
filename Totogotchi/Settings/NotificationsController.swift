import AppKit
import Combine
import UserNotifications

/// The Settings view's window onto reminders: the app's own switch, and what
/// macOS currently allows.
///
/// The two are deliberately separate. The user can silence Totogotchi without
/// touching System Settings, and macOS can refuse regardless of the switch.
@MainActor
final class NotificationsController: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { settings.notificationsEnabled = isEnabled }
    }
    @Published private(set) var systemStatus: UNAuthorizationStatus = .notDetermined

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        isEnabled = settings.notificationsEnabled
    }

    /// Re-read rather than cached, so granting permission in System Settings and
    /// coming back shows the new state without relaunching.
    func refreshStatus() async {
        systemStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// What to tell the user, or nil when there is nothing to explain.
    var systemWarning: String? {
        switch systemStatus {
        case .denied:
            return "macOS is blocking Totogotchi's notifications. Turn them on in System Settings, Notifications, Totogotchi."
        case .notDetermined:
            return "macOS has not been asked yet. The prompt appears the first time a task comes due."
        default:
            return nil
        }
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }
}
