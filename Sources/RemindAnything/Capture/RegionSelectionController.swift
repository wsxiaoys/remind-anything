import AppKit

/// Presents a full-screen crosshair overlay and lets the user drag to select a
/// rectangular region. Works over any source (including a browser tab) — it only
/// captures pixels; context is collected independently.
///
/// The returned rect is in **global top-left points**, matching
/// `SCDisplay.frame` used by `CaptureEngine.captureRegion`.
@MainActor
final class RegionSelectionController {
    private var window: OverlayWindow?
    private var completion: ((CGRect?) -> Void)?

    func begin(_ completion: @escaping (CGRect?) -> Void) {
        self.completion = completion

        // Present the overlay on the screen that currently contains the mouse
        // cursor, so region selection appears on whichever display has focus in
        // a multi-monitor setup — not just the primary display.
        let mouse = NSEvent.mouseLocation // AppKit bottom-left coordinates
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main
            ?? NSScreen.screens.first else {
            finish(nil)
            return
        }
        let frame = screen.frame

        let window = OverlayWindow(contentRect: frame,
                                   styleMask: .borderless,
                                   backing: .buffered,
                                   defer: false)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let view = SelectionView(frame: NSRect(origin: .zero, size: frame.size))
        view.onComplete = { [weak self] rectInWindow in
            self?.handleSelection(rectInWindow, windowOrigin: frame.origin)
        }
        view.onCancel = { [weak self] in
            self?.finish(nil)
        }
        window.contentView = view
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(view)
        self.window = window
    }

    private func handleSelection(_ rectInWindow: CGRect?, windowOrigin: CGPoint) {
        guard let rectInWindow, rectInWindow.width > 2, rectInWindow.height > 2 else {
            finish(nil)
            return
        }
        // Convert window-local (bottom-left) → global AppKit → global top-left.
        let globalBottomLeft = CGRect(x: rectInWindow.origin.x + windowOrigin.x,
                                      y: rectInWindow.origin.y + windowOrigin.y,
                                      width: rectInWindow.width,
                                      height: rectInWindow.height)
        let topLeft = Self.toTopLeft(globalBottomLeft)
        finish(topLeft)
    }

    private func finish(_ rect: CGRect?) {
        window?.orderOut(nil)
        window = nil
        let done = completion
        completion = nil
        done?(rect)
    }

    /// Convert an AppKit bottom-left global rect to a top-left global rect.
    static func toTopLeft(_ rect: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return rect }
        let primaryHeight = primary.frame.height
        return CGRect(x: rect.origin.x,
                      y: primaryHeight - rect.origin.y - rect.height,
                      width: rect.width,
                      height: rect.height)
    }
}

/// Borderless window that can become key so it receives keyDown (Esc to cancel).
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// The interactive crosshair + rubber-band selection view.
private final class SelectionView: NSView {
    var onComplete: ((CGRect?) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentRect: CGRect?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Dim the whole overlay.
        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()

        guard let rect = currentRect else { return }

        // Clear the selection (punch a hole).
        NSColor.clear.set()
        rect.fill(using: .copy)

        // Selection border.
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.5
        NSColor.controlAccentColor.setStroke()
        border.stroke()

        // Dimensions label.
        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = label.size(withAttributes: attrs)
        let labelOrigin = CGPoint(x: rect.midX - size.width / 2,
                                  y: max(rect.minY - size.height - 6, 4))
        let bg = CGRect(origin: CGPoint(x: labelOrigin.x - 5, y: labelOrigin.y - 3),
                        size: CGSize(width: size.width + 10, height: size.height + 6))
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: bg, xRadius: 4, yRadius: 4).fill()
        label.draw(at: labelOrigin, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let p = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(x: min(start.x, p.x),
                             y: min(start.y, p.y),
                             width: abs(p.x - start.x),
                             height: abs(p.y - start.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        onComplete?(currentRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}
