import AppKit
import ApplicationServices

/// Resolves the active tab URL + title for supported browsers.
///
/// The design calls for ScriptingBridge; here we use AppleScript (via
/// `NSAppleScript`) which needs no per-app generated headers and exercises the
/// same underlying scripting definitions. The result is cached-free and fast
/// enough for a single capture.
@MainActor
enum BrowserContext {

    /// Families of browsers that share AppleScript dictionaries.
    private enum Family {
        case chromium   // Chrome, Brave, Edge, Arc, Vivaldi, Chromium
        case safari
        case firefox    // AX fallback only
    }

    /// Bundle identifier → family map for supported browsers.
    private static let families: [String: Family] = [
        "com.google.Chrome": .chromium,
        "com.google.Chrome.beta": .chromium,
        "com.google.Chrome.canary": .chromium,
        "com.brave.Browser": .chromium,
        "com.microsoft.edgemac": .chromium,
        "company.thebrowser.Browser": .chromium, // Arc
        "com.vivaldi.Vivaldi": .chromium,
        "org.chromium.Chromium": .chromium,
        "com.apple.Safari": .safari,
        "com.apple.SafariTechnologyPreview": .safari,
        "org.mozilla.firefox": .firefox
    ]

    struct Page {
        var url: URL?
        var title: String?
    }

    /// Returns the active page for the given running app, or nil if it's not a
    /// supported browser (or the URL couldn't be read).
    static func activePage(for app: NSRunningApplication) -> Page? {
        guard let bundleID = app.bundleIdentifier,
              let family = families[bundleID],
              let appName = app.localizedName else { return nil }

        switch family {
        case .chromium:
            return chromiumPage(appName: appName)
        case .safari:
            return safariPage(appName: appName)
        case .firefox:
            return firefoxPage(pid: app.processIdentifier)
        }
    }

    // MARK: - Chromium family

    private static func chromiumPage(appName: String) -> Page? {
        let urlScript = """
        tell application "\(appName)" to get URL of active tab of front window
        """
        let titleScript = """
        tell application "\(appName)" to get title of active tab of front window
        """
        let urlString = runAppleScript(urlScript)
        let title = runAppleScript(titleScript)
        return Page(url: urlString.flatMap(URL.init(string:)), title: title)
    }

    // MARK: - Safari

    private static func safariPage(appName: String) -> Page? {
        let urlScript = "tell application \"\(appName)\" to get URL of front document"
        let titleScript = "tell application \"\(appName)\" to get name of front document"
        let urlString = runAppleScript(urlScript)
        let title = runAppleScript(titleScript)
        return Page(url: urlString.flatMap(URL.init(string:)), title: title)
    }

    // MARK: - Firefox (Accessibility fallback)

    private static func firefoxPage(pid: pid_t) -> Page? {
        guard AXIsProcessTrusted() else { return nil }
        // Best-effort: read the focused window title; the address bar value is
        // not reliably exposed, so we surface the title as page context.
        let appElement = AXUIElementCreateApplication(pid)
        if let title = axString(appElement, kAXTitleAttribute) {
            return Page(url: nil, title: title)
        }
        return nil
    }

    // MARK: - Helpers

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        let value = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    private static func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success else { return nil }
        return value as? String
    }
}
