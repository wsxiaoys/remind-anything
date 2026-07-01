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
