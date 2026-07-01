import SwiftUI
import Carbon.HIToolbox
import UserNotifications

/// The Settings window: hotkeys, default reminder, launch-at-login, permissions.
struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            hotkeysTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            permissionsTab
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 460, height: 360)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            Stepper(value: $settings.defaultReminderMinutes, in: 1...100_000, step: 5) {
                Text("Default reminder: in \(settings.defaultReminderMinutes) min")
            }
        }
        .padding(20)
    }

    // MARK: - Hotkeys

    private var hotkeysTab: some View {
        Form {
            LabeledContent("Capture Region") {
                HotkeyRecorder(hotkey: $settings.regionHotkey)
            }
            LabeledContent("Capture Window") {
                HotkeyRecorder(hotkey: $settings.windowHotkey)
            }
            LabeledContent("Capture Screen") {
                HotkeyRecorder(hotkey: $settings.screenHotkey)
            }
            Text("Click a shortcut, then press the new key combination.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    // MARK: - Permissions

    private var permissionsTab: some View {
        PermissionsView()
            .padding(20)
    }
}

// MARK: - Hotkey recorder

private struct HotkeyRecorder: View {
    @Binding var hotkey: Hotkey
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press keys…" : hotkey.displayString)
                .frame(minWidth: 90)
        }
        .buttonStyle(.bordered)
        .tint(recording ? .accentColor : nil)
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore modifier-only presses.
            let carbonMods = Self.carbonModifiers(from: event.modifierFlags)
            guard carbonMods != 0 else { return nil }
            hotkey = Hotkey(keyCode: UInt32(event.keyCode), modifiers: carbonMods)
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        return m
    }
}

// MARK: - Permissions view (shared with onboarding)

struct PermissionsView: View {
    @State private var notificationsAuthorized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            permissionRow(
                title: "Screen Recording",
                subtitle: "Required to capture windows, screens, and regions.",
                granted: Permissions.hasScreenRecording,
                action: { Permissions.requestScreenRecording() },
                openSettings: { Permissions.openPrivacyPane(.screenRecording) }
            )
            permissionRow(
                title: "Accessibility",
                subtitle: "Reads window titles and the Firefox address bar.",
                granted: Permissions.hasAccessibility,
                action: { Permissions.requestAccessibility() },
                openSettings: { Permissions.openPrivacyPane(.accessibility) }
            )
            permissionRow(
                title: "Notifications",
                subtitle: "Delivers your reminders when they fire.",
                granted: notificationsAuthorized,
                action: { Task { notificationsAuthorized = await NotificationScheduler.requestAuthorization() } },
                openSettings: { Permissions.openPrivacyPane(.notifications) }
            )
            Text("Automation permission for each browser is requested the first time you capture from it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task { await refreshNotificationStatus() }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsAuthorized = settings.authorizationStatus == .authorized
    }

    private func permissionRow(title: String,
                               subtitle: String,
                               granted: Bool,
                               action: @escaping () -> Void,
                               openSettings: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("Granted").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    Button("Request", action: action)
                    Button("Settings", action: openSettings)
                }
            }
        }
    }
}
