import AppKit
import SwiftUI
import SwiftData
import UserNotifications

/// Wires up notifications, global hotkeys, login-item reconciliation, and
/// first-run onboarding.
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    private var hotkeyIDs: [UInt32] = []
    private var onboardingWindow: NSWindow?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app.
        NSApp.setActivationPolicy(.accessory)

        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.registerCategories()

        MainActor.assumeIsolated {
            registerHotkeys()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(hotkeysChanged),
                name: AppSettings.hotkeysChanged,
                object: nil
            )
            // Re-check permissions when the app is reactivated so the menu's
            // Welcome row reflects grants made in System Settings while running.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: NSApplication.didBecomeActiveNotification,
                object: nil
            )
        }

        Task { @MainActor in
            _ = await NotificationScheduler.requestAuthorization()
            await Permissions.refresh()
            reconcileReminders()
            showOnboardingIfNeeded()
        }
    }

    @objc private func appDidBecomeActive() {
        Task { @MainActor in await Permissions.refresh() }
    }

    // MARK: - Hotkeys

    @MainActor
    private func registerHotkeys() {
        let settings = AppSettings.shared
        HotkeyManager.shared.unregisterAll()
        hotkeyIDs.removeAll()

        hotkeyIDs.append(HotkeyManager.shared.register(settings.regionHotkey) {
            CaptureCoordinator.shared.capture(mode: .region)
        })
        hotkeyIDs.append(HotkeyManager.shared.register(settings.windowHotkey) {
            CaptureCoordinator.shared.capture(mode: .window)
        })
        hotkeyIDs.append(HotkeyManager.shared.register(settings.screenHotkey) {
            CaptureCoordinator.shared.capture(mode: .fullScreen)
        })
    }

    @objc private func hotkeysChanged() {
        MainActor.assumeIsolated { registerHotkeys() }
    }

    // MARK: - Reconcile

    @MainActor
    private func reconcileReminders() {
        let context = Store.shared.mainContext
        let descriptor = FetchDescriptor<Reminder>()
        if let reminders = try? context.fetch(descriptor) {
            NotificationScheduler.reconcile(pending: reminders)
        }
    }

    // MARK: - Onboarding

    @MainActor
    private func showOnboardingIfNeeded() {
        let key = "didCompleteOnboarding"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let root = OnboardingView { [weak self] in
            UserDefaults.standard.set(true, forKey: key)
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    // MARK: - Notification handling

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let idString = info["reminderID"] as? String,
              let id = UUID(uuidString: idString) else { return }

        let action = NotificationScheduler.Action(rawValue: response.actionIdentifier)
        let urlString = info["url"] as? String

        await MainActor.run {
            handle(action: action,
                   defaultAction: response.actionIdentifier == UNNotificationDefaultActionIdentifier,
                   reminderID: id,
                   urlString: urlString)
        }
    }

    @MainActor
    private func handle(action: NotificationScheduler.Action?,
                        defaultAction: Bool,
                        reminderID: UUID,
                        urlString: String?) {
        let context = Store.shared.mainContext
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.id == reminderID }
        )
        let reminder: Reminder? = (try? context.fetch(descriptor))?.first

        func openTarget() {
            if let urlString, let url = URL(string: urlString), url.scheme != nil {
                NSWorkspace.shared.open(url)
            } else if let reminder {
                // No URL — reveal the screenshot file in Finder.
                let fileURL = AppPaths.captureURL(forRelativePath: reminder.imagePath)
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
        }

        switch action {
        case .some(.snooze10):
            snooze(reminder, minutes: 10)
        case .some(.snooze60):
            snooze(reminder, minutes: 60)
        case .some(.snoozeTomorrow):
            snooze(reminder, minutes: 60 * 24)
        case .some(.done):
            reminder?.status = .completed
            NotificationScheduler.cancel(id: reminderID)
        default:
            // .open, the default action, or a dismiss → open the target.
            // Opening keeps the reminder in progress until the user
            // completes or archives it.
            openTarget()
        }

        try? context.save()
    }

    /// "Snooze" is just rescheduling: push the fire date out and re-arm the
    /// notification. The reminder stays `inProgress` the whole time.
    @MainActor
    private func snooze(_ reminder: Reminder?, minutes: Int) {
        guard let reminder else { return }
        reminder.fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        reminder.status = .inProgress
        NotificationScheduler.cancel(reminder)
        NotificationScheduler.schedule(reminder)
    }
}
