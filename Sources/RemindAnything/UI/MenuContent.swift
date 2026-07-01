import SwiftUI

/// The dropdown shown from the menu bar status item.
struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var permissions = PermissionsMonitor.shared

    var body: some View {
        Button {
            openWindow(id: "preferences")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("Preferences…", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        if !permissions.allGranted {
            Button {
                openWindow(id: "onboarding")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Welcome to Remind Anything…", systemImage: "hand.wave")
            }
        }

        Divider()

        Button {
            openWindow(id: "library")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("Open Library…", systemImage: "square.grid.2x2")
        }

        Divider()

        Button {
            CaptureCoordinator.shared.capture(mode: .region)
        } label: {
            Label("Capture Region", systemImage: "crop")
        }
        .keyboardShortcut("2", modifiers: [.option, .shift])

        Button {
            CaptureCoordinator.shared.capture(mode: .window)
        } label: {
            Label("Capture Window", systemImage: "macwindow")
        }
        .keyboardShortcut("1", modifiers: [.option, .shift])

        Button {
            CaptureCoordinator.shared.capture(mode: .fullScreen)
        } label: {
            Label("Capture Screen", systemImage: "display")
        }
        .keyboardShortcut("3", modifiers: [.option, .shift])

        Divider()

        Button("Quit Remind Anything") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
