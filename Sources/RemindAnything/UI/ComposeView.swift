import SwiftUI

/// The compose panel: thumbnail, editable context chips, note field, and a
/// schedule picker (relative presets, with a "Custom" option to pick an exact
/// date & time).
struct ComposeView: View {
    @ObservedObject var draft: CaptureDraft
    let onSave: () -> Void
    let onCancel: () -> Void

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
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
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
        SchedulePickerView(scheduleKind: $draft.scheduleKind,
                           relativeMinutes: $draft.relativeMinutes,
                           absoluteDate: $draft.absoluteDate)
    }

    private var actionButtons: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.shadcn(.outline))
            Spacer()
            Button("Save", action: onSave)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.shadcn(.primary))
        }
    }
}
