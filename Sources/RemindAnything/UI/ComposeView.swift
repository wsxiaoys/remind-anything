import SwiftUI

/// The compose panel: thumbnail, editable context chips, note field, and a
/// schedule picker (At / In / Every).
struct ComposeView: View {
    @ObservedObject var draft: CaptureDraft
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            thumbnail
            contextChips
            noteField
            Divider()
            schedulePicker
            Spacer(minLength: 0)
            actionButtons
        }
        .padding(16)
        .frame(width: 380)
        .frame(minHeight: 520)
    }

    // MARK: - Sections

    private var thumbnail: some View {
        Image(nsImage: draft.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
    }

    private var contextChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let app = draft.sourceApp, !app.isEmpty {
                chip(icon: "app.dashed", text: app)
            }
            if draft.hasURL {
                chip(icon: "link", text: draft.urlString)
            } else if let title = draft.windowTitle, !title.isEmpty {
                chip(icon: "macwindow", text: title)
            }
        }
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Note").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $draft.note)
                .font(.body)
                .frame(height: 70)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
        }
    }

    private var schedulePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $draft.scheduleKind) {
                ForEach(ScheduleKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch draft.scheduleKind {
            case .relative:  relativeControls
            case .absolute:  absoluteControls
            case .recurring: recurringControls
            }
        }
    }

    private var relativeControls: some View {
        HStack {
            Stepper(value: $draft.relativeMinutes, in: 1...100_000, step: 5) {
                Text("In \(formatMinutes(draft.relativeMinutes))")
            }
        }
    }

    private var absoluteControls: some View {
        DatePicker("At", selection: $draft.absoluteDate, in: Date()...)
            .datePickerStyle(.compact)
    }

    private var recurringControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Every", selection: $draft.recurrence) {
                ForEach(RecurrencePreset.allCases) { p in
                    Text(p.label).tag(p)
                }
            }
            if draft.recurrence != .hourly {
                DatePicker("At", selection: $draft.recurringTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            Button("Cancel", role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Save Reminder", action: onSave)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }
}
