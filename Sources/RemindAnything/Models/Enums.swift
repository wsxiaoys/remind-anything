import Foundation

/// How a reminder's fire time is derived.
enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
    case absolute   // fire at a specific date/time ("At")
    case relative   // fire after a delay ("In")

    var id: String { rawValue }

    var label: String {
        switch self {
        case .absolute:  return "At"
        case .relative:  return "In"
        }
    }
}

/// Lifecycle state of a reminder.
///
/// Modeled after a Slack-style workflow: a reminder is either actively
/// waiting to fire (`inProgress`), dismissed without completing
/// (`archived`), or finished (`completed`). Snoozing is *not* a state —
/// it simply reschedules the reminder to a later time.
enum ReminderStatus: String, Codable, CaseIterable, Identifiable {
    case inProgress
    case archived
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inProgress: return "In Progress"
        case .archived:   return "Archived"
        case .completed:  return "Completed"
        }
    }

    /// Decode a stored raw value, migrating pre-Slack-model values.
    ///
    /// Legacy statuses map as: `done` → `completed`; `scheduled`, `fired`,
    /// and `snoozed` → `inProgress`.
    static func fromStored(_ raw: String) -> ReminderStatus {
        if let value = ReminderStatus(rawValue: raw) { return value }
        switch raw {
        case "done":      return .completed
        case "scheduled", "fired", "snoozed": return .inProgress
        default:          return .inProgress
        }
    }
}

/// The capture mode chosen by the user (each has its own hotkey).
enum CaptureMode: String, CaseIterable, Identifiable {
    case region      // default fast path — crosshair crop over any source
    case window      // frontmost window
    case fullScreen  // whole display under cursor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .region:     return "Region"
        case .window:     return "Window"
        case .fullScreen: return "Full Screen"
        }
    }

    var systemImage: String {
        switch self {
        case .region:     return "crop"
        case .window:     return "macwindow"
        case .fullScreen: return "display"
        }
    }
}
