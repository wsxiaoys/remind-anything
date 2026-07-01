import Foundation

/// Centralized on-disk locations used by the app.
///
/// Layout:
/// ~/Library/Application Support/RemindAnything/
///   ├── RemindAnything.store        (SwiftData sqlite)
///   └── captures/
///        ├── <uuid>.png             (full screenshot)
///        └── <uuid>-thumb.png       (thumbnail)
enum AppPaths {
    static let bundleFolderName = "RemindAnything"

    static var appSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(bundleFolderName, isDirectory: true)
        ensureDir(dir)
        return dir
    }

    static var capturesDir: URL {
        let dir = appSupport.appendingPathComponent("captures", isDirectory: true)
        ensureDir(dir)
        return dir
    }

    static var storeURL: URL {
        appSupport.appendingPathComponent("RemindAnything.store")
    }

    /// Absolute URL for a path stored relative to `capturesDir`.
    static func captureURL(forRelativePath relative: String) -> URL {
        capturesDir.appendingPathComponent(relative)
    }

    static func relativeCapturePath(for filename: String) -> String {
        filename
    }

    private static func ensureDir(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
