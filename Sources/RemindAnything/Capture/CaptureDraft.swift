import AppKit
import Combine

/// Slack-style quick presets for the "In" (relative) schedule picker, so users
/// can pick common timeframes without fiddling with a minute stepper.
enum RelativePreset: String, CaseIterable, Identifiable {
    case min30
    case hour1
    case hour3
    case tomorrow
    case nextWeek
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .min30:    return "In 30 minutes"
        case .hour1:    return "In 1 hour"
        case .hour3:    return "In 3 hours"
        case .tomorrow: return "Tomorrow"
        case .nextWeek: return "Next week"
        case .custom:   return "Pick date & time…"
        }
    }

    /// How a preset maps onto the draft's schedule inputs.
    enum Resolution {
        case relative(minutes: Int)  // fire after a fixed delay
        case absolute(Date)          // fire at a specific wall-clock time
        case custom                  // user picks an exact date & time
    }

    /// Resolve this preset relative to `now`.
    ///
    /// Short presets (30 min / 1 / 3 hours) stay *relative* delays, but
    /// `Tomorrow` and `Next week` resolve to an *absolute* 9:00 AM — matching
    /// Slack's morning-reminder behaviour. `Next week` lands on the coming
    /// Monday morning rather than exactly 7 days later. Using an absolute date
    /// (instead of a minutes-from-now offset) keeps the fire time pinned exactly
    /// to 9:00 AM rather than drifting to 8:59 due to fractional-minute
    /// truncation and the delay between picking and saving.
    func resolution(now: Date = Date(), calendar: Calendar = .current) -> Resolution {
        switch self {
        case .min30: return .relative(minutes: 30)
        case .hour1: return .relative(minutes: 60)
        case .hour3: return .relative(minutes: 180)
        case .tomorrow: return .absolute(Self.morning(of: Self.day(from: now, afterDays: 1, calendar: calendar), calendar: calendar))
        case .nextWeek: return .absolute(Self.morning(of: Self.nextMonday(from: now, calendar: calendar), calendar: calendar))
        case .custom: return .custom
        }
    }

    private static func day(from now: Date, afterDays days: Int, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: days, to: startOfDay) ?? now
    }

    /// The Monday of next week (relative to a Monday-based week), always
    /// strictly in the future.
    private static func nextMonday(from now: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: now)
        // Calendar weekday: 1 = Sunday, 2 = Monday, … 7 = Saturday.
        let weekday = calendar.component(.weekday, from: startOfDay)
        // Days to the upcoming Monday (0 if today is Monday, 1 if Sunday, …).
        let toUpcomingMonday = ((2 - weekday) + 7) % 7
        // If today is Monday, jump a full week; otherwise the upcoming Monday
        // already belongs to next week.
        let offset = toUpcomingMonday == 0 ? 7 : toUpcomingMonday
        return calendar.date(byAdding: .day, value: offset, to: startOfDay) ?? startOfDay
    }

    private static func morning(of day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }
}

/// Mutable, in-flight capture the compose panel edits before it becomes a
/// persisted `Reminder`.
@MainActor
final class CaptureDraft: ObservableObject {
    let id = UUID()
    let image: NSImage

    @Published var note: String = ""

    // Context (editable chips)
    @Published var sourceApp: String?
    @Published var windowTitle: String?
    @Published var urlString: String
    @Published var pageTitle: String?

    // Schedule
    @Published var scheduleKind: ScheduleKind = .relative
    @Published var relativeMinutes: Int = 60
    @Published var absoluteDate: Date = Date().addingTimeInterval(3600)

    init(image: NSImage, context: CaptureContext) {
        self.image = image
        self.sourceApp = context.sourceApp
        self.windowTitle = context.windowTitle
        self.urlString = context.url?.absoluteString ?? ""
        self.pageTitle = context.pageTitle
    }

    var hasURL: Bool { URL(string: urlString)?.scheme != nil }

    /// Resolve the schedule inputs into (kind, fireDate).
    func resolvedSchedule() -> (kind: ScheduleKind, fireDate: Date) {
        switch scheduleKind {
        case .relative:
            let fire = Date().addingTimeInterval(TimeInterval(max(1, relativeMinutes) * 60))
            return (.relative, fire)
        case .absolute:
            return (.absolute, absoluteDate)
        }
    }

    /// Persist the image to disk and build a `Reminder` (not yet inserted).
    func makeReminder() throws -> Reminder {
        let saved = try ImageStore.save(image, id: id)
        let schedule = resolvedSchedule()
        let url = URL(string: urlString.trimmingCharacters(in: .whitespaces))
        return Reminder(
            id: id,
            imagePath: saved.imageRelativePath,
            thumbnailPath: saved.thumbnailRelativePath,
            sourceApp: sourceApp,
            windowTitle: windowTitle,
            url: (url?.scheme != nil) ? url : nil,
            pageTitle: pageTitle,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            scheduleKind: schedule.kind,
            fireDate: schedule.fireDate,
            status: .scheduled
        )
    }
}
