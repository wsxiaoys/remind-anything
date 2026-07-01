import AppKit
import ScreenCaptureKit

/// Silent screen/window/region capture built on ScreenCaptureKit.
///
/// Unlike the macOS screenshot picker, this never shows a system dialog — the
/// app owns the whole capture flow (region overlay is provided separately by
/// `RegionSelectionController`).
struct CaptureEngine {

    /// Result of a capture: the image plus any window that was targeted.
    struct Result {
        var image: NSImage
        var window: SCWindow?
        var display: SCDisplay?
    }

    // MARK: - Full screen

    /// Capture the entire display currently under the mouse cursor.
    func captureFullScreen() async throws -> Result {
        let content = try await shareableContent()
        let display = try displayUnderCursor(content)
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let cg = try await capture(filter: filter,
                                   width: display.width,
                                   height: display.height)
        return Result(image: ImageStore.png(from: cg), window: nil, display: display)
    }

    // MARK: - Frontmost window

    /// Capture the frontmost window without any drag interaction.
    func captureFrontWindow() async throws -> Result {
        let content = try await shareableContent()
        guard let window = frontmostWindow(content) else {
            // Fall back to full screen if no on-screen window can be found.
            return try await captureFullScreen()
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let width = Int(window.frame.width)
        let height = Int(window.frame.height)
        let cg = try await capture(filter: filter,
                                   width: max(width, 1),
                                   height: max(height, 1))
        return Result(image: ImageStore.png(from: cg), window: window, display: nil)
    }

    // MARK: - Region

    /// Capture a rectangular region (in global/top-left screen points) by
    /// grabbing the containing display and cropping.
    func captureRegion(_ rect: CGRect) async throws -> Result {
        let content = try await shareableContent()
        // Choose the display that contains the region's origin.
        let display = try display(containing: rect.origin, in: content)
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let scale = displayScaleFactor(for: display)
        let full = try await capture(filter: filter,
                                     width: Int(CGFloat(display.width) * scale),
                                     height: Int(CGFloat(display.height) * scale))

        // Convert the region from global top-left points into display-local pixels.
        let localX = (rect.origin.x - CGFloat(display.frame.origin.x)) * scale
        let localY = (rect.origin.y - CGFloat(display.frame.origin.y)) * scale
        let cropRect = CGRect(x: localX,
                              y: localY,
                              width: rect.width * scale,
                              height: rect.height * scale).integral

        guard let cropped = full.cropping(to: cropRect) else {
            return Result(image: ImageStore.png(from: full), window: nil, display: display)
        }
        return Result(image: ImageStore.png(from: cropped), window: nil, display: display)
    }

    // MARK: - Core capture

    private func capture(filter: SCContentFilter, width: Int, height: Int) async throws -> CGImage {
        let config = SCStreamConfiguration()
        config.width = max(width, 1)
        config.height = max(height, 1)
        config.showsCursor = false
        config.scalesToFit = false
        config.captureResolution = .best
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }

    // MARK: - Shareable content helpers

    private func shareableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureError.noContent
        }
    }

    private func displayUnderCursor(_ content: SCShareableContent) throws -> SCDisplay {
        let mouse = NSEvent.mouseLocation // bottom-left origin (AppKit)
        let topLeft = globalTopLeftPoint(fromAppKit: mouse)
        return try display(containing: topLeft, in: content)
    }

    private func display(containing point: CGPoint, in content: SCShareableContent) throws -> SCDisplay {
        if let match = content.displays.first(where: { $0.frame.contains(point) }) {
            return match
        }
        guard let first = content.displays.first else { throw CaptureError.noDisplay }
        return first
    }

    private func frontmostWindow(_ content: SCShareableContent) -> SCWindow? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        let candidates = content.windows.filter { window in
            window.owningApplication?.processID == pid &&
            window.isOnScreen &&
            window.frame.width > 40 &&
            window.frame.height > 40 &&
            window.windowLayer == 0
        }
        // Prefer the window with the largest area (the main document window).
        return candidates.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    }

    private func displayScaleFactor(for display: SCDisplay) -> CGFloat {
        let screen = NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
        }
        return screen?.backingScaleFactor ?? 2
    }

    /// Convert an AppKit (bottom-left origin) point to a global top-left point,
    /// matching ScreenCaptureKit's `SCDisplay.frame` coordinate space.
    private func globalTopLeftPoint(fromAppKit p: CGPoint) -> CGPoint {
        guard let main = NSScreen.screens.first else { return p }
        let totalHeight = main.frame.height
        return CGPoint(x: p.x, y: totalHeight - p.y)
    }
}
