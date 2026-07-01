import AppKit
import SwiftData

/// Orchestrates a capture end-to-end: collect context → grab pixels → present
/// the compose panel.
@MainActor
final class CaptureCoordinator: ObservableObject {
    static let shared = CaptureCoordinator()

    private let engine = CaptureEngine()
    private let regionController = RegionSelectionController()
    private let panel = ComposePanelController()

    @Published var isCapturing = false

    private init() {}

    func capture(mode: CaptureMode) {
        guard !isCapturing else { return }
        Task { await performCapture(mode: mode) }
    }

    private func performCapture(mode: CaptureMode) async {
        guard Permissions.hasScreenRecording else {
            Permissions.requestScreenRecording()
            presentError("Screen Recording permission is required. Grant it in System Settings, then try again.")
            return
        }

        isCapturing = true
        defer { isCapturing = false }

        do {
            let result: CaptureEngine.Result
            let context: CaptureContext
            switch mode {
            case .fullScreen:
                context = ContextCollector.collect()
                result = try await engine.captureFullScreen()
            case .window:
                context = ContextCollector.collect()
                result = try await engine.captureFrontWindow()
            case .region:
                // Present the crosshair overlay IMMEDIATELY for a snappy feel.
                // Snapshot the frontmost app first (instant) so its context —
                // including a browser tab's URL — can still be collected after
                // the overlay steals focus. The (slow) browser/AX queries then
                // run off the critical path instead of delaying the overlay.
                let frontApp = NSWorkspace.shared.frontmostApplication
                guard let rect = await selectRegion() else { return } // cancelled
                // Prefer the app owning the window *under the selected region* so
                // context is right even when keyboard focus is on another window
                // or display; fall back to the pre-overlay frontmost app.
                let probe = CGPoint(x: rect.midX, y: rect.midY)
                let targetApp = ContextCollector.appUnderPoint(probe) ?? frontApp
                context = ContextCollector.collect(frontApp: targetApp)
                // Give the overlay a beat to disappear before grabbing pixels.
                try? await Task.sleep(nanoseconds: 120_000_000)
                result = try await engine.captureRegion(rect)
            }

            // Copy to the clipboard so the app doubles as a screenshot tool.
            if AppSettings.shared.copyScreenshotToClipboard {
                ImageStore.copyToPasteboard(result.image)
            }

            presentCompose(image: result.image, context: context)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func selectRegion() async -> CGRect? {
        await withCheckedContinuation { continuation in
            regionController.begin { rect in
                continuation.resume(returning: rect)
            }
        }
    }

    private func presentCompose(image: NSImage, context: CaptureContext) {
        let draft = CaptureDraft(image: image, context: context)
        panel.present(draft: draft) { reminder in
            let ctx = Store.shared.mainContext
            ctx.insert(reminder)
            try? ctx.save()
            NotificationScheduler.schedule(reminder)
        }
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Capture Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
