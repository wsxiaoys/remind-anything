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

    @Published var launchAtLogin: Bool {
        didSet { updateLoginItem(launchAtLogin) }
    }

    /// When enabled, every capture is also copied to the clipboard so the app
    /// doubles as a screenshot tool. Defaults to ON.
    @Published var copyScreenshotToClipboard: Bool {
        didSet { defaults.set(copyScreenshotToClipboard, forKey: Keys.copyToClipboard) }
    }

    /// Posted whenever a hotkey changes so listeners can re-register.
    static let hotkeysChanged = Notification.Name("RemindAnything.hotkeysChanged")

    private enum Keys {
        static let region = "hotkey.region"
        static let window = "hotkey.window"
        static let screen = "hotkey.screen"
        static let didConfigureLoginItem = "loginItem.didConfigureDefault"
        static let copyToClipboard = "capture.copyToClipboard"
    }

    private init() {
        self.regionHotkey = AppSettings.load(Keys.region, default: .defaultRegion, defaults: defaults)
        self.windowHotkey = AppSettings.load(Keys.window, default: .defaultWindow, defaults: defaults)
        self.screenHotkey = AppSettings.load(Keys.screen, default: .defaultScreen, defaults: defaults)

        // Copy captures to the clipboard by default so the app can be used as a
        // general screenshot tool. `object(forKey:)` is nil for a fresh install,
        // in which case we default to true.
        self.copyScreenshotToClipboard = defaults.object(forKey: Keys.copyToClipboard) as? Bool ?? true

        // Launch at login defaults to ON for a fresh install so users don't miss
        // reminders after a reboot; afterwards we honor the user's own choice.
        let hasConfiguredLoginItem = defaults.bool(forKey: Keys.didConfigureLoginItem)
        self.launchAtLogin = hasConfiguredLoginItem ? (SMAppService.mainApp.status == .enabled) : true

        if !hasConfiguredLoginItem {
            defaults.set(true, forKey: Keys.didConfigureLoginItem)
            updateLoginItem(true)
        }
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
