import SwiftUI

/// The compose panel: thumbnail, editable context chips, note field, and a
/// schedule picker (At / In).
struct ComposeView: View {
    @ObservedObject var draft: CaptureDraft
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var relativePreset: RelativePreset = .hour1
    @State private var showNote = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            thumbnail
            contextChips
            noteField
            Divider()
            schedulePicker
            actionButtons
        }
        .padding(16)
        .frame(width: 380)
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

    @ViewBuilder
    private var noteField: some View {
        if showNote {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Note").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        draft.note = ""
                        showNote = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove note")
                }
                TextEditor(text: $draft.note)
                    .font(.body)
                    .focused($noteFocused)
                    .frame(height: 70)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
            }
        } else {
            Button {
                showNote = true
                noteFocused = true
            } label: {
                Label("Add note", systemImage: "plus.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
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
            }
        }
    }

    private var relativeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Remind me", selection: $relativePreset) {
                ForEach(RelativePreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .onChange(of: relativePreset) { _, newValue in
                if let minutes = newValue.minutesFromNow() {
                    draft.relativeMinutes = minutes
                }
            }

            if relativePreset == .custom {
                Stepper(value: $draft.relativeMinutes, in: 1...100_000, step: 5) {
                    Text("In \(formatMinutes(draft.relativeMinutes))")
                }
            }

            Text("Reminds \(relativeFireDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var relativeFireDate: Date {
        Date().addingTimeInterval(TimeInterval(max(1, draft.relativeMinutes) * 60))
    }

    private var absoluteControls: some View {
        DatePicker("At", selection: $draft.absoluteDate, in: Date()...)
            .datePickerStyle(.compact)
    }

    private var actionButtons: some View {
        HStack {
            Button("Cancel", role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Save", action: onSave)
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
