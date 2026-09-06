import Foundation

/// User preferences, stored in the app's sandboxed defaults.
final class AppSettings {
    private enum Key {
        static let hotKey = "hotKey"
        static let fallbackNoticeShownFor = "fallbackNoticeShownFor"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The shortcut that opens quick capture. Falls back to the shipped default
    /// when nothing is stored or the stored value cannot be read.
    var hotKey: HotKeyCombo {
        get {
            guard let data = defaults.data(forKey: Key.hotKey),
                  let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data)
            else { return .default }
            return combo
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.hotKey)
        }
    }

    /// Remembers which unavailable shortcut the user has already been told about,
    /// so the launch notice appears once rather than on every start.
    func shouldShowFallbackNotice(for combo: HotKeyCombo) -> Bool {
        defaults.string(forKey: Key.fallbackNoticeShownFor) != combo.description
    }

    func recordFallbackNoticeShown(for combo: HotKeyCombo) {
        defaults.set(combo.description, forKey: Key.fallbackNoticeShownFor)
    }
}
