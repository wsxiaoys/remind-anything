import AppKit
import CoreGraphics
import ApplicationServices
import ScreenCaptureKit

/// Thin wrappers around the various TCC permission checks the app relies on.
@MainActor
enum Permissions {
    /// Screen Recording — required for any capture.
    static var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
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
