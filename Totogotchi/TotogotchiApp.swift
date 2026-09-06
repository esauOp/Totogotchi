import SwiftUI

@main
struct TotogotchiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app has no Dock icon and no main window; every window it shows is
        // built in AppDelegate. `App` still needs one scene, and an empty
        // Settings scene is the cheapest that adds no visible chrome. The real
        // Settings window is SettingsWindowController's, because the scene's
        // command needs a menu bar that an LSUIElement app does not have.
        Settings { EmptyView() }
    }
}
