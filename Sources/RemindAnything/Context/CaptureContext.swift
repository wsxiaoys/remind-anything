import Foundation

/// Contextual metadata captured alongside the screenshot pixels.
struct CaptureContext: Sendable {
    var sourceApp: String?
    var windowTitle: String?
    var url: URL?
    var pageTitle: String?

    static let empty = CaptureContext()
}
