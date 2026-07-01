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

        let hosting = NSHostingView(rootView: root)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
                            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.title = "New Reminder"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.center()

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
