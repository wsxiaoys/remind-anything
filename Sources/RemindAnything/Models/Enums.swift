import Foundation

/// How a reminder's fire time is derived.
enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
    case absolute   // fire at a specific date/time ("At")
    case relative   // fire after a delay ("In")
    case recurring  // fire on a repeating calendar rule ("Every")

    var id: String { rawValue }

    var label: String {
        switch self {
        case .absolute:  return "At"
        case .relative:  return "In"
        case .recurring: return "Every"
        }
    }
}

/// Lifecycle state of a reminder.
enum ReminderStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled
    case fired
    case done
    case snoozed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .fired:     return "Fired"
        case .done:      return "Done"
        case .snoozed:   return "Snoozed"
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
