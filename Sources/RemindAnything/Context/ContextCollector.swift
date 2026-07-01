import AppKit
import ApplicationServices
import CoreGraphics

/// Snapshots the frontmost app, its window title, and (for browsers) the active
/// tab URL + title. Runs independently of the capture mode so a region crop of a
/// browser tab still records that tab's URL.
@MainActor
enum ContextCollector {

    /// Collect context for `frontApp`, defaulting to the current frontmost app.
    ///
    /// Region capture passes a pre-snapshotted `frontApp` so the (potentially
    /// slow) browser/Accessibility queries can run *after* the crosshair overlay
    /// is on screen, without the overlay's focus change corrupting the result —
    /// Apple Events and AX target the app by reference/pid, not by frontmost.
    static func collect(frontApp: NSRunningApplication? = nil) -> CaptureContext {
        var ctx = CaptureContext()

        guard let frontApp = frontApp ?? NSWorkspace.shared.frontmostApplication else {
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

    /// The application owning the topmost standard on-screen window at a global
    /// top-left `point`. Used so a region capture records the context of the
    /// window *under the selection* rather than whichever window happens to hold
    /// keyboard focus (which may be on another display entirely).
    static func appUnderPoint(_ point: CGPoint) -> NSRunningApplication? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]] else { return nil }

        let ownPID = getpid()
        // The list is ordered front-to-back, so the first match is the topmost.
        for info in infoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let boundsDict = info[kCGWindowBounds as String],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary),
                  bounds.contains(point) else { continue }
            return NSRunningApplication(processIdentifier: pid)
        }
        return nil
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
