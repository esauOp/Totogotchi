import Combine
import ServiceManagement
import os

/// Whether Totogotchi starts with the session.
///
/// The state is read from `SMAppService.status` every time, never from a stored
/// preference. A boolean in defaults would drift the moment the user removed the
/// app from login items in System Settings, and the switch would then be lying
/// about something the user can see elsewhere.
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    /// Set when macOS declined, or wants the user's approval first.
    @Published private(set) var statusMessage: String?

    private let service = SMAppService.mainApp
    private let log = Logger(subsystem: "com.esauortega.Totogotchi", category: "login")

    init() {
        refresh()
    }

    /// Re-reads the system state. Called whenever Settings appears, so a change
    /// made outside the app shows up.
    func refresh() {
        switch service.status {
        case .enabled:
            isEnabled = true
            statusMessage = nil
        case .requiresApproval:
            isEnabled = false
            statusMessage = "macOS needs your approval before Totogotchi can start at login. Allow it in System Settings, General, Login Items."
        case .notFound:
            isEnabled = false
            statusMessage = "macOS cannot register this copy of Totogotchi. That usually means it is running from a build folder rather than from Applications."
        case .notRegistered:
            isEnabled = false
            statusMessage = nil
        @unknown default:
            isEnabled = false
            statusMessage = nil
        }
    }

    /// Turns the login item on or off, then re-reads the truth rather than
    /// assuming the call worked.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
                log.info("Registered as a login item")
            } else {
                try service.unregister()
                log.info("Unregistered as a login item")
            }
            statusMessage = nil
        } catch {
            log.error("Login item change refused: \(String(describing: error), privacy: .public)")
            statusMessage = "macOS refused: \(error.localizedDescription)"
        }
        refresh()
    }
}
