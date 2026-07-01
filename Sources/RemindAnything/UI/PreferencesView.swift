import SwiftUI
import Carbon.HIToolbox
import UserNotifications

/// The Settings window, styled after the "Handy" app: a left sidebar with
/// vertical tabs and a right-hand content area of grouped, card-style sections.
struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var selection: PrefTab = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(width: 660, height: 460)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preferences")
                .font(.title3.bold())
                .padding(.horizontal, 12)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ForEach(PrefTab.allCases) { tab in
                sidebarRow(tab)
            }

            Spacer()
        }
        .frame(width: 200, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func sidebarRow(_ tab: PrefTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                Text(tab.title)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            }
            // Make the whole row (including padding / spacer gaps) clickable.
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                switch selection {
                case .general:     generalContent
                case .shortcuts:   shortcutsContent
                case .permissions: permissionsContent
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - General

    private var generalContent: some View {
        SettingsSection(header: "App") {
            SettingRow(
                title: "Launch at login",
                description: "Open Remind Anything automatically when you sign in."
            ) {
                Toggle("", isOn: $settings.launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            Divider()
            SettingRow(
                title: "Copy screenshots to clipboard",
                description: "Also copy every capture to the clipboard so you can paste it anywhere."
            ) {
                Toggle("", isOn: $settings.copyScreenshotToClipboard)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    // MARK: - Shortcuts

    private var shortcutsContent: some View {
        SettingsSection(
            header: "Capture Shortcuts",
            footer: "Click a shortcut, then press the new key combination."
        ) {
            SettingRow(title: "Capture Region") {
                HotkeyRecorder(hotkey: $settings.regionHotkey)
            }
            Divider()
            SettingRow(title: "Capture Window") {
                HotkeyRecorder(hotkey: $settings.windowHotkey)
            }
            Divider()
            SettingRow(title: "Capture Screen") {
                HotkeyRecorder(hotkey: $settings.screenHotkey)
            }
        }
    }

    // MARK: - Permissions

    private var permissionsContent: some View {
        SettingsSection(header: "Permissions") {
            PermissionsView()
        }
    }
}

// MARK: - Tabs

private enum PrefTab: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:     return "General"
        case .shortcuts:   return "Shortcuts"
        case .permissions: return "Permissions"
        }
    }

    var icon: String {
        switch self {
        case .general:     return "gearshape"
        case .shortcuts:   return "keyboard"
        case .permissions: return "lock.shield"
        }
    }
}

// MARK: - Reusable card / row components

/// A titled, card-style group of setting rows.
struct SettingsSection<Content: View>: View {
    let header: String
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // No distinct card fill — blend with the window background and
                // rely on a subtle border to delineate the group.
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.15))
            }

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A single setting row: title (+ optional description) on the left, a control
/// aligned to the right.
struct SettingRow<Control: View>: View {
    let title: String
    var description: String? = nil
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            control
        }
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
                action: { Task { notificationsAuthorized = await NotificationScheduler.requestAuthorization(); await Permissions.refreshNotificationsStatus() } },
                openSettings: { Permissions.openPrivacyPane(.notifications) }
            )
            Text("Automation permission for each browser is requested the first time you capture from it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task { await refreshNotificationStatus() }
    }

    private func refreshNotificationStatus() async {
        notificationsAuthorized = await Permissions.refreshNotificationsStatus()
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
