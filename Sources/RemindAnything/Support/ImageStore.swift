import AppKit
import UniformTypeIdentifiers

/// Handles writing capture images + thumbnails to disk and generating thumbnails.
enum ImageStore {
    static let thumbnailMaxDimension: CGFloat = 320

    struct SavedImages {
        let imageRelativePath: String
        let thumbnailRelativePath: String
    }

    /// Persists a capture image (and a generated thumbnail) to the captures dir.
    /// Returns relative paths suitable for storing in a `Reminder`.
    static func save(_ image: NSImage, id: UUID) throws -> SavedImages {
        let baseName = id.uuidString
        let imageName = "\(baseName).png"
        let thumbName = "\(baseName)-thumb.png"

        let imageURL = AppPaths.captureURL(forRelativePath: imageName)
        let thumbURL = AppPaths.captureURL(forRelativePath: thumbName)

        guard let imageData = pngData(from: image) else {
            throw CaptureError.encodingFailed
        }
        try imageData.write(to: imageURL, options: .atomic)

        let thumb = thumbnail(from: image)
        if let thumbData = pngData(from: thumb) {
            try? thumbData.write(to: thumbURL, options: .atomic)
        }

        return SavedImages(
            imageRelativePath: AppPaths.relativeCapturePath(for: imageName),
            thumbnailRelativePath: AppPaths.relativeCapturePath(for: thumbName)
        )
    }

    static func delete(imageRelativePath: String?, thumbnailRelativePath: String?) {
        for rel in [imageRelativePath, thumbnailRelativePath].compactMap({ $0 }) {
            let url = AppPaths.captureURL(forRelativePath: rel)
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func loadImage(relativePath: String?) -> NSImage? {
        guard let relativePath else { return nil }
        let url = AppPaths.captureURL(forRelativePath: relativePath)
        return NSImage(contentsOf: url)
    }

    // MARK: - Helpers

    static func thumbnail(from image: NSImage) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(1, thumbnailMaxDimension / max(size.width, size.height))
        let target = NSSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1)
        thumb.unlockFocus()
        return thumb
    }

    static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    static func png(from cgImage: CGImage) -> NSImage {
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

enum CaptureError: LocalizedError {
    case noContent
    case noDisplay
    case cancelled
    case encodingFailed
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .noContent:            return "No shareable screen content was available."
        case .noDisplay:            return "Could not find a display to capture."
        case .cancelled:            return "Capture was cancelled."
        case .encodingFailed:       return "Failed to encode the captured image."
        case .captureFailed(let m): return "Capture failed: \(m)"
        }
    }
}
