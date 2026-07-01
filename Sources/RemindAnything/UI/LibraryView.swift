import SwiftUI
import SwiftData
import AppKit

/// Browse / search / manage captured reminders.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Reminder.createdAt, order: .reverse) private var reminders: [Reminder]

    @State private var searchText = ""
    @State private var statusFilter: ReminderStatus? = nil
    @State private var selection: Reminder.ID?

    private var filtered: [Reminder] {
        reminders.filter { reminder in
            let matchesStatus = statusFilter == nil || reminder.status == statusFilter
            let matchesSearch = searchText.isEmpty
                || reminder.note.localizedCaseInsensitiveContains(searchText)
                || (reminder.url?.absoluteString.localizedCaseInsensitiveContains(searchText) ?? false)
                || (reminder.sourceApp?.localizedCaseInsensitiveContains(searchText) ?? false)
                || (reminder.windowTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesStatus && matchesSearch
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 720, minHeight: 460)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                List(filtered, selection: $selection) { reminder in
                    ReminderRow(reminder: reminder)
                        .tag(reminder.id)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 300)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search notes, URLs, apps")
    }

    private var filterBar: some View {
        Picker("Filter", selection: $statusFilter) {
            Text("All").tag(ReminderStatus?.none)
            ForEach(ReminderStatus.allCases) { status in
                Text(status.label).tag(ReminderStatus?.some(status))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No reminders yet")
                .foregroundStyle(.secondary)
            Text("Press ⌥⇧2 to capture a region.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let selection, let reminder = reminders.first(where: { $0.id == selection }) {
            ReminderDetailView(reminder: reminder) { deleteReminder(reminder) }
        } else {
            ContentUnavailableView("Select a Reminder",
                                   systemImage: "sidebar.left",
                                   description: Text("Choose a capture to see its details."))
        }
    }

    private func deleteReminder(_ reminder: Reminder) {
        NotificationScheduler.cancel(reminder)
        ImageStore.delete(imageRelativePath: reminder.imagePath,
                          thumbnailRelativePath: reminder.thumbnailPath)
        context.delete(reminder)
        try? context.save()
        selection = nil
    }
}

// MARK: - Row

private struct ReminderRow: View {
    let reminder: Reminder

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.note.isEmpty ? "(no note)" : reminder.note)
                    .lineLimit(1)
                    .font(.body)
                Text(reminder.contextSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            StatusBadge(status: reminder.status)
        }
        .padding(.vertical, 2)
    }

    private var thumbnail: some View {
        Group {
            if let image = ImageStore.loadImage(relativePath: reminder.thumbnailPath ?? reminder.imagePath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .frame(width: 48, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct StatusBadge: View {
    let status: ReminderStatus

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .scheduled: return .blue
        case .snoozed:   return .orange
        case .fired:     return .purple
        case .done:      return .green
        }
    }
}

// MARK: - Detail

private struct ReminderDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var reminder: Reminder
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = ImageStore.loadImage(relativePath: reminder.imagePath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                }

                Text(reminder.note.isEmpty ? "(no note)" : reminder.note)
                    .font(.title3)

                infoGrid

                HStack {
                    if reminder.url != nil {
                        Button {
                            reopen()
                        } label: {
                            Label("Reopen", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Menu {
                        Button("Snooze 10 min") { snooze(minutes: 10) }
                        Button("Snooze 1 hour") { snooze(minutes: 60) }
                        Button("Tomorrow") { snooze(minutes: 60 * 24) }
                    } label: {
                        Label("Snooze", systemImage: "clock")
                    }
                    Button {
                        markDone()
                    } label: {
                        Label("Done", systemImage: "checkmark.circle")
                    }
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .padding(20)
        }
    }

    private var infoGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Status", reminder.status.label)
            row("Fires", reminder.effectiveFireDate.formatted(date: .abbreviated, time: .shortened))
            if reminder.scheduleKind == .recurring, let rule = reminder.recurrenceRule {
                row("Repeats", rule)
            }
            if let app = reminder.sourceApp { row("App", app) }
            if let title = reminder.windowTitle { row("Window", title) }
            if let url = reminder.url { row("URL", url.absoluteString) }
            row("Captured", reminder.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(3)
            Spacer()
        }
    }

    private func reopen() {
        if let url = reminder.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func snooze(minutes: Int) {
        reminder.snoozedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        reminder.status = .snoozed
        try? context.save()
        NotificationScheduler.cancel(reminder)
        NotificationScheduler.schedule(reminder)
    }

    private func markDone() {
        reminder.status = .done
        try? context.save()
        NotificationScheduler.cancel(reminder)
    }
}
