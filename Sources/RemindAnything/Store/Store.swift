import Foundation
import SwiftData

/// Provides the shared SwiftData model container backed by a file in
/// Application Support.
enum Store {
    static let shared: ModelContainer = {
        let schema = Schema([Reminder.self])
        let config = ModelConfiguration(
            schema: schema,
            url: AppPaths.storeURL,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fall back to an in-memory store so the app still launches; the
            // user is notified via the console and library will simply be empty.
            NSLog("RemindAnything: failed to open persistent store: \(error). Falling back to in-memory.")
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [memConfig])
        }
    }()
}
