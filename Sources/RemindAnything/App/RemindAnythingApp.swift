import SwiftUI

@main
struct RemindAnythingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Remind Anything", systemImage: "bell.badge") {
            MenuContent()
        }
        .menuBarExtraStyle(.menu)

        Window("Reminders", id: "library") {
            LibraryView()
                .modelContainer(Store.shared)
        }
        .defaultSize(width: 820, height: 520)

        // Preferences is a normal Window scene (not the SwiftUI `Settings`
        // scene) because an accessory / menu-bar-only app can reliably bring a
        // `Window` to the front via `openWindow` + `NSApp.activate`, whereas the
        // `Settings` scene stays behind the focused app.
        Window("Preferences", id: "preferences") {
            PreferencesView()
        }
        .windowResizability(.contentSize)

        // Reopenable welcome / onboarding window (feedback #3).
        Window("Welcome", id: "onboarding") {
            OnboardingWindow()
        }
        .windowResizability(.contentSize)
    }
}

/// Wraps `OnboardingView` for the reopenable `Window` scene, marking onboarding
/// complete and dismissing itself when the user finishes.
private struct OnboardingWindow: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        OnboardingView {
            UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
            dismiss()
        }
    }
}
