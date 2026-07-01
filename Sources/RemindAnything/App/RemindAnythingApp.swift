import SwiftUI

@main
struct RemindAnythingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Remind Anything", systemImage: "bell.badge") {
            MenuContent()
        }
        .menuBarExtraStyle(.menu)

        Window("Library", id: "library") {
            LibraryView()
                .modelContainer(Store.shared)
        }
        .defaultSize(width: 820, height: 520)

        Settings {
            PreferencesView()
        }
    }
}
