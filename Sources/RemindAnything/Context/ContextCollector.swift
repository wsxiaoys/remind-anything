import AppKit
import ApplicationServices

/// Snapshots the frontmost app, its window title, and (for browsers) the active
/// tab URL + title. Runs independently of the capture mode so a region crop of a
/// browser tab still records that tab's URL.
@MainActor
enum ContextCollector {

    static func collect() -> CaptureContext {
        var ctx = CaptureContext()

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return ctx
        }
        ctx.sourceApp = frontApp.localizedName
        ctx.windowTitle = focusedWindowTitle(pid: frontApp.processIdentifier)

        if let page = BrowserContext.activePage(for: frontApp) {
            ctx.url = page.url
            ctx.pageTitle = page.title
            // Prefer the page title as the window title context for browsers.
            if let t = page.title, !t.isEmpty { ctx.windowTitle = t }
        }

        return ctx
    }

    /// Reads the focused window's title via Accessibility (requires permission).
    private static func focusedWindowTitle(pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        let err = AXUIElementCopyAttributeValue(appElement,
                                                kAXFocusedWindowAttribute as CFString,
                                                &focusedWindow)
        guard err == .success, let window = focusedWindow else { return nil }

        var title: AnyObject?
        let titleErr = AXUIElementCopyAttributeValue(window as! AXUIElement,
                                                     kAXTitleAttribute as CFString,
                                                     &title)
        guard titleErr == .success else { return nil }
        let str = (title as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (str?.isEmpty == false) ? str : nil
    }
}
