import Foundation
import ServiceManagement
import Combine

/// User-configurable settings, persisted in `UserDefaults`.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var regionHotkey: Hotkey { didSet { save(regionHotkey, key: Keys.region); notifyHotkeys() } }
    @Published var windowHotkey: Hotkey { didSet { save(windowHotkey, key: Keys.window); notifyHotkeys() } }
    @Published var screenHotkey: Hotkey { didSet { save(screenHotkey, key: Keys.screen); notifyHotkeys() } }

    @Published var defaultReminderMinutes: Int {
        didSet { defaults.set(defaultReminderMinutes, forKey: Keys.defaultMinutes) }
    }

    @Published var launchAtLogin: Bool {
        didSet { updateLoginItem(launchAtLogin) }
    }

    /// Posted whenever a hotkey changes so listeners can re-register.
    static let hotkeysChanged = Notification.Name("RemindAnything.hotkeysChanged")

    private enum Keys {
        static let region = "hotkey.region"
        static let window = "hotkey.window"
        static let screen = "hotkey.screen"
        static let defaultMinutes = "reminder.defaultMinutes"
    }

    private init() {
        self.regionHotkey = AppSettings.load(Keys.region, default: .defaultRegion, defaults: defaults)
        self.windowHotkey = AppSettings.load(Keys.window, default: .defaultWindow, defaults: defaults)
        self.screenHotkey = AppSettings.load(Keys.screen, default: .defaultScreen, defaults: defaults)
        let minutes = defaults.integer(forKey: Keys.defaultMinutes)
        self.defaultReminderMinutes = minutes == 0 ? 60 : minutes
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    // MARK: - Persistence helpers

    private func save(_ hotkey: Hotkey, key: String) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load(_ key: String, default fallback: Hotkey, defaults: UserDefaults) -> Hotkey {
        guard let data = defaults.data(forKey: key),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return fallback
        }
        return hotkey
    }

    private func notifyHotkeys() {
        NotificationCenter.default.post(name: AppSettings.hotkeysChanged, object: nil)
    }

    // MARK: - Login item

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("RemindAnything: failed to update login item: \(error)")
        }
    }
}
