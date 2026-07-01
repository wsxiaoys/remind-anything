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
        case .custom:   return "Custom…"
        }
    }

    /// Minutes from `now` this preset resolves to, or `nil` for `.custom`
    /// (which lets the user enter an arbitrary interval).
    ///
    /// `Tomorrow` and `Next week` land on 9:00 AM, matching the Slack behaviour
    /// of reminding in the morning rather than exactly 24 hours / 7 days later.
    func minutesFromNow(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        switch self {
        case .min30: return 30
        case .hour1: return 60
        case .hour3: return 180
        case .tomorrow: return Self.minutes(from: now, toMorningAfterDays: 1, calendar: calendar)
        case .nextWeek: return Self.minutes(from: now, toMorningAfterDays: 7, calendar: calendar)
        case .custom: return nil
        }
    }

    private static func minutes(from now: Date, toMorningAfterDays days: Int, calendar: Calendar) -> Int {
        let startOfDay = calendar.startOfDay(for: now)
        let targetDay = calendar.date(byAdding: .day, value: days, to: startOfDay) ?? now
        let target = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDay) ?? targetDay
        let seconds = target.timeIntervalSince(now)
        return max(1, Int(seconds / 60))
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
