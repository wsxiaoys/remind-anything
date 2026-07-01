import Foundation
import SwiftData

/// Persistent metadata for a single capture + reminder.
///
/// Large binary data (the PNG screenshot and thumbnail) live on disk under
/// Application Support; only the relative paths are stored here so the DB stays
/// small and queryable.
@Model
final class Reminder {
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    // MARK: Capture
    var imagePath: String          // relative path to PNG under captures/
    var thumbnailPath: String?     // relative path to thumbnail PNG

    // MARK: Context
    var sourceApp: String?         // e.g. "Google Chrome"
    var windowTitle: String?
    var url: URL?                  // present when captured from a browser
    var pageTitle: String?

    // MARK: User input
    var note: String

    // MARK: Scheduling
    var scheduleKindRaw: String
    var fireDate: Date
    var recurrenceRule: String?    // RFC 5545-ish, optional
    var snoozedUntil: Date?

    // MARK: State
    var statusRaw: String

    var scheduleKind: ScheduleKind {
        get { ScheduleKind(rawValue: scheduleKindRaw) ?? .absolute }
        set { scheduleKindRaw = newValue.rawValue }
    }

    var status: ReminderStatus {
        get { ReminderStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        imagePath: String,
        thumbnailPath: String? = nil,
        sourceApp: String? = nil,
        windowTitle: String? = nil,
        url: URL? = nil,
        pageTitle: String? = nil,
        note: String,
        scheduleKind: ScheduleKind,
        fireDate: Date,
        recurrenceRule: String? = nil,
        snoozedUntil: Date? = nil,
        status: ReminderStatus = .scheduled
    ) {
        self.id = id
        self.createdAt = createdAt
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.sourceApp = sourceApp
        self.windowTitle = windowTitle
        self.url = url
        self.pageTitle = pageTitle
        self.note = note
        self.scheduleKindRaw = scheduleKind.rawValue
        self.fireDate = fireDate
        self.recurrenceRule = recurrenceRule
        self.snoozedUntil = snoozedUntil
        self.statusRaw = status.rawValue
    }
}

extension Reminder {
    /// A short, human-readable context line for lists and notifications.
    var contextSummary: String {
        if let host = url?.host { return host }
        if let app = sourceApp { return app }
        return windowTitle ?? "Capture"
    }

    /// A meaningful title for the capture. Falls back to the richest piece of
    /// captured context (page/window title, app, or host) when the user hasn't
    /// typed a note yet.
    var displayTitle: String {
        if !note.isEmpty { return note }
        if let title = pageTitle?.trimmed, !title.isEmpty { return title }
        if let title = windowTitle?.trimmed, !title.isEmpty {
            if let app = sourceApp?.trimmed, !app.isEmpty {
                return "\(title) — \(app)"
            }
            return title
        }
        if let app = sourceApp?.trimmed, !app.isEmpty { return "Capture from \(app)" }
        if let host = url?.host { return "Capture from \(host)" }
        return "Untitled capture"
    }

    /// Whether `displayTitle` is derived from context rather than a user note.
    var hasNote: Bool { !note.isEmpty }

    var effectiveFireDate: Date {
        snoozedUntil ?? fireDate
    }
}

private extension String {
    /// Whitespace/newline-trimmed copy.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
