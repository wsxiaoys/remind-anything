import Foundation
import UserNotifications
import AppKit

/// Bridges reminders to `UNUserNotificationCenter`, including trigger
/// construction, thumbnail attachments, and notification actions.
@MainActor
enum NotificationScheduler {

    static let categoryID = "REMIND_ANYTHING_REMINDER"

    enum Action: String {
        case open        = "OPEN"
        case snooze10    = "SNOOZE_10"
        case snooze60    = "SNOOZE_60"
        case snoozeTomorrow = "SNOOZE_TOMORROW"
        case done        = "DONE"
    }

    // MARK: - Setup

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            NSLog("RemindAnything: notification authorization error: \(error)")
            return false
        }
    }

    static func registerCategories() {
        let open = UNNotificationAction(identifier: Action.open.rawValue,
                                        title: "Open",
                                        options: [.foreground])
        let snooze10 = UNNotificationAction(identifier: Action.snooze10.rawValue,
                                            title: "Snooze 10 min")
        let snooze60 = UNNotificationAction(identifier: Action.snooze60.rawValue,
                                            title: "Snooze 1 hour")
        let snoozeTomorrow = UNNotificationAction(identifier: Action.snoozeTomorrow.rawValue,
                                                  title: "Tomorrow")
        let done = UNNotificationAction(identifier: Action.done.rawValue,
                                        title: "Done",
                                        options: [.destructive])

        let category = UNNotificationCategory(identifier: categoryID,
                                              actions: [open, snooze10, snooze60, snoozeTomorrow, done],
                                              intentIdentifiers: [],
                                              options: [.customDismissAction])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Scheduling

    static func schedule(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.note.isEmpty ? "Reminder" : reminder.note
        content.body = reminder.contextSummary
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = [
            "reminderID": reminder.id.uuidString,
            "url": reminder.url?.absoluteString ?? "",
            "imagePath": reminder.imagePath
        ]

        if let thumbRel = reminder.thumbnailPath,
           let attachment = makeAttachment(relativePath: thumbRel, id: reminder.id) {
            content.attachments = [attachment]
        }

        guard let trigger = makeTrigger(for: reminder) else {
            NSLog("RemindAnything: skipping schedule for past/invalid fire date")
            return
        }

        let request = UNNotificationRequest(identifier: reminder.id.uuidString,
                                            content: content,
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { NSLog("RemindAnything: failed to schedule: \(error)") }
        }
    }

    static func cancel(_ reminder: Reminder) {
        cancel(id: reminder.id)
    }

    static func cancel(id: UUID) {
        let ids = [id.uuidString]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Re-register all reminders that should still fire (call at launch).
    static func reconcile(pending reminders: [Reminder]) {
        let now = Date()
        for reminder in reminders where reminder.status == .scheduled || reminder.status == .snoozed {
            if reminder.effectiveFireDate > now {
                schedule(reminder)
            }
        }
    }

    // MARK: - Triggers

    private static func makeTrigger(for reminder: Reminder) -> UNNotificationTrigger? {
        let fireDate = reminder.effectiveFireDate

        switch reminder.scheduleKind {
        case .relative:
            let interval = fireDate.timeIntervalSinceNow
            guard interval > 0 else { return nil }
            return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        case .absolute:
            guard fireDate > Date() else { return nil }
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        }
    }

    // MARK: - Attachments

    private static func makeAttachment(relativePath: String, id: UUID) -> UNNotificationAttachment? {
        let source = AppPaths.captureURL(forRelativePath: relativePath)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }
        // Copy into a temp location UN owns/manages.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ra-\(id.uuidString).png")
        try? FileManager.default.removeItem(at: tmp)
        do {
            try FileManager.default.copyItem(at: source, to: tmp)
            return try UNNotificationAttachment(identifier: id.uuidString, url: tmp, options: nil)
        } catch {
            return nil
        }
    }
}
