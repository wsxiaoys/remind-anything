import AppKit
import CoreGraphics
import ApplicationServices
import ScreenCaptureKit
import UserNotifications

/// Thin wrappers around the various TCC permission checks the app relies on.
@MainActor
enum Permissions {
    /// Screen Recording — required for any capture.
    static var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Cached notifications authorization. Notifications status can only be read
    /// asynchronously, so we cache the latest value (refreshed at launch and
    /// whenever the permissions UI appears) for synchronous callers like the
    /// menu bar.
    static private(set) var hasNotifications: Bool = false

    /// Refreshes and returns the cached notifications authorization flag.
    @discardableResult
    static func refreshNotificationsStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        hasNotifications = settings.authorizationStatus == .authorized
        return hasNotifications
    }

    /// True once every required permission has been granted. Used to hide
    /// onboarding entry points once the user is fully set up.
    static var allGranted: Bool {
        hasScreenRecording && hasAccessibility && hasNotifications
    }

    @discardableResult
    static func requestScreenRecording() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Accessibility — required to read window titles / focused elements
    /// (and the Firefox address-bar fallback).
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibility() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Opens the relevant System Settings pane.
    static func openPrivacyPane(_ pane: PrivacyPane) {
        if let url = URL(string: pane.urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    enum PrivacyPane {
        case screenRecording
        case accessibility
        case automation
        case notifications

        var urlString: String {
            switch self {
            case .screenRecording:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            case .accessibility:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .automation:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
            case .notifications:
                return "x-apple.systempreferences:com.apple.preference.notifications"
            }
        }
    }
}
