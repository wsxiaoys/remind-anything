import AppKit
import SwiftUI

/// Owns the floating, non-activating compose panel and hosts the SwiftUI
/// `ComposeView` inside it.
@MainActor
final class ComposePanelController {
    private var panel: NSPanel?

    func present(draft: CaptureDraft, onSave: @escaping (Reminder) -> Void) {
        // Close any existing panel first.
        dismiss()

        let root = ComposeView(
            draft: draft,
            onSave: { [weak self] in
                do {
                    let reminder = try draft.makeReminder()
                    onSave(reminder)
                    self?.dismiss()
                } catch {
                    NSSound.beep()
                    NSLog("RemindAnything: failed to save reminder: \(error)")
                }
            },
            onCancel: { [weak self] in self?.dismiss() }
        )

        // Host in an NSHostingController with `.preferredContentSize` so the
        // panel resizes to fit the SwiftUI content — including when the note
        // section is expanded or collapsed — instead of a fixed height.
        let hostingController = NSHostingController(rootView: root)
        hostingController.sizingOptions = [.preferredContentSize]

        let panel = NSPanel(contentViewController: hostingController)
        panel.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
        panel.title = "New Reminder"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        centerOnActiveScreen(panel)

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    /// Center the panel on the display under the mouse cursor (where the capture
    /// just happened) instead of the main display, so the compose dialog appears
    /// on the same screen the user is working on in a multi-monitor setup.
    private func centerOnActiveScreen(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main ?? NSScreen.screens.first else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = CGPoint(x: visible.midX - size.width / 2,
                             y: visible.midY - size.height / 2)
        panel.setFrameOrigin(origin)
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
