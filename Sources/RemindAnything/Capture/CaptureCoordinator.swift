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

        // Collect context BEFORE we alter focus (e.g. showing the region overlay),
        // so a browser tab's URL is still readable.
        let context = ContextCollector.collect()

        do {
            let result: CaptureEngine.Result
            switch mode {
            case .fullScreen:
                result = try await engine.captureFullScreen()
            case .window:
                result = try await engine.captureFrontWindow()
            case .region:
                guard let rect = await selectRegion() else { return } // cancelled
                // Give the overlay a beat to disappear before grabbing pixels.
                try? await Task.sleep(nanoseconds: 120_000_000)
                result = try await engine.captureRegion(rect)
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
