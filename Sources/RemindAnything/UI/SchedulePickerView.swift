import SwiftUI

/// The shared schedule picker used by both the capture compose panel and the
/// library reschedule flow: relative presets (In 30 min / 1 hour / …), plus a
/// "Custom" option that reveals Slack-style date & time dropdowns.
///
/// Operates on plain bindings so it can drive either a `CaptureDraft` (create
/// flow) or a `Reminder`'s in-flight edit state (library reschedule flow).
struct SchedulePickerView: View {
    @Binding var scheduleKind: ScheduleKind
    @Binding var relativeMinutes: Int
    @Binding var absoluteDate: Date

    @State private var relativePreset: RelativePreset

    init(scheduleKind: Binding<ScheduleKind>,
         relativeMinutes: Binding<Int>,
         absoluteDate: Binding<Date>,
         initialPreset: RelativePreset = .hour1) {
        self._scheduleKind = scheduleKind
        self._relativeMinutes = relativeMinutes
        self._absoluteDate = absoluteDate
        self._relativePreset = State(initialValue: initialPreset)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Remind me", selection: $relativePreset) {
                ForEach(RelativePreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .onChange(of: relativePreset) { _, newValue in
                switch newValue.resolution() {
                case .relative(let minutes):
                    scheduleKind = .relative
                    relativeMinutes = minutes
                case .absolute(let date):
                    // Fixed wall-clock presets (Tomorrow / Next week) pin the
                    // fire time exactly, avoiding minute-drift.
                    scheduleKind = .absolute
                    absoluteDate = date
                case .custom:
                    // Custom → pick an exact date & time (absolute schedule),
                    // snapped to a fixed 15-minute increment like Slack.
                    scheduleKind = .absolute
                    absoluteDate = Self.roundedUpToQuarterHour(absoluteDate)
                }
            }

            if relativePreset == .custom {
                HStack(spacing: 8) {
                    PickerField(icon: "calendar",
                                text: absoluteDate.formatted(date: .abbreviated, time: .omitted)) { _ in
                        DatePicker("", selection: $absoluteDate, in: Date()...,
                                   displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .frame(width: 260)
                            .padding(12)
                    }
                    PickerField(icon: "clock",
                                text: absoluteDate.formatted(date: .omitted, time: .shortened)) { dismiss in
                        TimeListPicker(selection: $absoluteDate, onPick: dismiss)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                remindsSummary
            }
        }
    }

    private var remindsSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(fireDatePreview.formatted(date: .abbreviated, time: .shortened))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var fireDatePreview: Date {
        switch scheduleKind {
        case .absolute:
            return absoluteDate
        case .relative:
            return Date().addingTimeInterval(TimeInterval(max(1, relativeMinutes) * 60))
        }
    }

    /// Round a date up to the next 15-minute boundary (seconds zeroed) so the
    /// custom time always aligns with the fixed increments in the time list.
    private static func roundedUpToQuarterHour(_ date: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        let remainder = minute % 15
        comps.minute = minute - remainder
        let floored = cal.date(from: comps) ?? date
        return remainder == 0 ? floored : (cal.date(byAdding: .minute, value: 15, to: floored) ?? floored)
    }
}

/// A Slack-style "dropdown" field: a bordered pill showing an icon + value and a
/// chevron, which reveals a picker in a popover when tapped. The `content`
/// builder receives a `dismiss` closure so a selection can close the popover.
private struct PickerField<PickerContent: View>: View {
    let icon: String
    let text: String
    @ViewBuilder var content: (@escaping () -> Void) -> PickerContent

    @State private var isPresented = false
    @State private var isHovering = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isPresented ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(isPresented || isHovering ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(isPresented ? 0.28 : 0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isPresented)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            content({ isPresented = false })
        }
    }
}

/// A Slack-style scrollable list of selectable times (fixed 15-minute
/// increments) for the day of the bound date. Selecting one keeps the date's day
/// and updates the time, then dismisses the popover.
private struct TimeListPicker: View {
    @Binding var selection: Date
    let onPick: () -> Void

    var body: some View {
        let times = Self.times(onDayOf: selection)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(times, id: \.self) { time in
                        TimeRow(time: time, isSelected: isSelected(time)) {
                            selection = time
                            onPick()
                        }
                        .id(time)
                    }
                }
                .padding(6)
            }
            .frame(width: 176, height: 248)
            .onAppear {
                if let match = times.first(where: isSelected) {
                    proxy.scrollTo(match, anchor: .center)
                }
            }
        }
    }

    private func isSelected(_ time: Date) -> Bool {
        Calendar.current.isDate(time, equalTo: selection, toGranularity: .minute)
    }

    private static func times(onDayOf date: Date) -> [Date] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let all = (0..<96).compactMap {
            cal.date(byAdding: .minute, value: $0 * 15, to: startOfDay)
        }
        if cal.isDateInToday(date) {
            let now = Date()
            return all.filter { $0 > now }
        }
        return all
    }
}

/// A single selectable row in `TimeListPicker`, with hover + selection states.
private struct TimeRow: View {
    let time: Date
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(fillColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var fillColor: Color {
        if isSelected { return Color.primary.opacity(0.10) }
        if isHovering { return Color.primary.opacity(0.06) }
        return .clear
    }
}
