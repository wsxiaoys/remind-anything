import AppKit
import Combine

/// Simple recurrence presets exposed in the compose UI.
enum RecurrencePreset: String, CaseIterable, Identifiable {
    case hourly
    case daily
    case weekly

    var id: String { rawValue }
    var label: String {
        switch self {
        case .hourly: return "Hour"
        case .daily:  return "Day"
        case .weekly: return "Week"
        }
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
    @Published var recurrence: RecurrencePreset = .daily
    @Published var recurringTime: Date = Date().addingTimeInterval(3600)

    init(image: NSImage, context: CaptureContext) {
        self.image = image
        self.sourceApp = context.sourceApp
        self.windowTitle = context.windowTitle
        self.urlString = context.url?.absoluteString ?? ""
        self.pageTitle = context.pageTitle
    }

    var hasURL: Bool { URL(string: urlString)?.scheme != nil }

    /// Resolve the schedule inputs into (kind, fireDate, recurrenceRule).
    func resolvedSchedule() -> (kind: ScheduleKind, fireDate: Date, rule: String?) {
        switch scheduleKind {
        case .relative:
            let fire = Date().addingTimeInterval(TimeInterval(max(1, relativeMinutes) * 60))
            return (.relative, fire, nil)
        case .absolute:
            return (.absolute, absoluteDate, nil)
        case .recurring:
            let rule: String
            switch recurrence {
            case .hourly: rule = "hourly"
            case .daily:  rule = "daily"
            case .weekly:
                let weekday = Calendar.current.component(.weekday, from: recurringTime)
                rule = "weekly:\(weekday)"
            }
            return (.recurring, recurringTime, rule)
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
            recurrenceRule: schedule.rule,
            status: .scheduled
        )
    }
}
