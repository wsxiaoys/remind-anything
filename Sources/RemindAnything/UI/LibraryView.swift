import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import QuickLook

/// Browse / search / manage captured reminders.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Reminder.createdAt, order: .reverse) private var reminders: [Reminder]

    @State private var searchText = ""
    @State private var statusFilter: ReminderStatus = .inProgress
    @State private var selection: Reminder.ID?

    private var filtered: [Reminder] {
        reminders.filter { reminder in
            let matchesStatus = reminder.status == statusFilter
            let matchesSearch = searchText.isEmpty
                || reminder.note.localizedCaseInsensitiveContains(searchText)
                || (reminder.url?.absoluteString.localizedCaseInsensitiveContains(searchText) ?? false)
                || (reminder.sourceApp?.localizedCaseInsensitiveContains(searchText) ?? false)
                || (reminder.windowTitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesStatus && matchesSearch
        }
    }

    private func count(for status: ReminderStatus) -> Int {
        reminders.reduce(into: 0) { $0 += ($1.status == status ? 1 : 0) }
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
            tabBar
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

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(ReminderStatus.allCases) { status in
                TabButton(
                    title: status.label,
                    count: count(for: status),
                    isSelected: statusFilter == status
                ) {
                    statusFilter = status
                    selection = nil
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    /// True when the user has typed a search query — used to show a
    /// search-specific empty state instead of the status-based one.
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: emptyStateIcon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(emptyStateTitle)
                .foregroundStyle(.secondary)
            if isSearching {
                Text("No matches in \(statusFilter.label).")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if statusFilter == .inProgress {
                Text("Press ⌥⇧2 to capture a region.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateIcon: String {
        if isSearching { return "magnifyingglass" }
        switch statusFilter {
        case .inProgress: return "bell.slash"
        case .archived:   return "archivebox"
        case .completed:  return "checkmark.circle"
        }
    }

    private var emptyStateTitle: String {
        if isSearching { return "No results" }
        switch statusFilter {
        case .inProgress: return "Nothing in progress"
        case .archived:   return "Nothing archived"
        case .completed:  return "Nothing completed yet"
        }
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
        VStack(alignment: .leading, spacing: 4) {
            if let due = dueLine {
                Text(due.text)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(due.color)
                    .lineLimit(1)
            }
            HStack(spacing: 10) {
                thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.displayTitle)
                        .lineLimit(1)
                        .font(.body)
                        .foregroundStyle(reminder.hasNote ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    Text(reminder.contextSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    /// Slack-style relative due line, e.g. "Due in 19 minutes" (or overdue).
    /// Shown only for in-progress reminders — under Archived/Completed the
    /// due time is no longer meaningful.
    private var dueLine: (text: String, color: Color)? {
        guard reminder.status == .inProgress else { return nil }
        let rel = Self.relativeFormatter.localizedString(for: reminder.fireDate, relativeTo: Date())
        let isOverdue = reminder.fireDate < Date()
        // Kept intentionally understated: a muted secondary tone for upcoming
        // reminders, a soft orange only when something is actually overdue.
        return ("Due \(rel)", isOverdue ? .orange : .secondary)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

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

// MARK: - Slack-style tab

private struct TabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                Rectangle()
                    .fill(isSelected ? Color.accentColor : .clear)
                    .frame(height: 2)
                    .clipShape(Capsule())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail

private struct ReminderDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var reminder: Reminder
    let onDelete: () -> Void

    // Reschedule editor state — mirrors the create-flow schedule inputs so the
    // library reuses the exact same picker component.
    @State private var showReschedule = false
    @State private var editScheduleKind: ScheduleKind = .relative
    @State private var editRelativeMinutes: Int = 60
    @State private var editAbsoluteDate: Date = Date().addingTimeInterval(3600)

    /// Drives the system Quick Look panel. Non-nil while a preview is open;
    /// the panel resets this to nil when dismissed.
    @State private var quickLookURL: URL?

    /// Whether the pointer is over the screenshot — reveals the Quick Look
    /// button in the corner.
    @State private var isHoveringImage = false

    /// Absolute on-disk URL of the full screenshot, used by Quick Look,
    /// "Reveal in Finder", and the save panel.
    private var imageURL: URL {
        AppPaths.captureURL(forRelativePath: reminder.imagePath)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    noteView

                    if let image = ImageStore.loadImage(relativePath: reminder.imagePath) {
                        screenshotView(image)
                    }

                    infoGrid
                }
                .padding(20)
            }

            Divider()

            actionBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .quickLookPreview($quickLookURL)
    }

    /// The detail screenshot. Hovering reveals a Quick Look button in the
    /// top-right corner; right-click exposes copy / reveal / save actions.
    private func screenshotView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
            .overlay(alignment: .topTrailing) { quickLookButton }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onHover { isHoveringImage = $0 }
            .contextMenu {
                Button("Quick Look") { openQuickLook() }
                Button("Copy Image") { ImageStore.copyToPasteboard(image) }
                Divider()
                Button("Save Image…") { saveImage(image) }
                Button("Reveal in Finder") { revealInFinder() }
            }
    }

    /// Hover-revealed Quick Look affordance shown in the screenshot's corner.
    private var quickLookButton: some View {
        Button(action: openQuickLook) {
            Image(systemName: "eye")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(6)
                .background(.black.opacity(0.55), in: Circle())
        }
        .buttonStyle(.plain)
        .pointingHandOnHover()
        .help("Quick Look")
        .padding(8)
        .opacity(isHoveringImage ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHoveringImage)
    }

    private func openQuickLook() {
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return }
        quickLookURL = imageURL
    }

    private func revealInFinder() {
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([imageURL])
    }

    /// Presents a save panel so the user can export the screenshot as a PNG.
    private func saveImage(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(reminder.displayTitle).png"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? ImageStore.pngData(from: image)?.write(to: url, options: .atomic)
    }

    private var noteView: some View {
        Text(reminder.displayTitle)
            .font(.title3)
            .fontWeight(.semibold)
            .textSelection(.enabled)
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            if reminder.status == .inProgress {
                HStack(spacing: 8) {
                    Button {
                        startReschedule()
                    } label: {
                        Label("Remind later", systemImage: "clock")
                    }
                    .buttonStyle(.shadcn(.secondary, fillWidth: true))
                    .popover(isPresented: $showReschedule, arrowEdge: .top) {
                        reschedulePopover
                    }
                    Button {
                        markCompleted()
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.shadcn(.secondary, fillWidth: true))
                }
                HStack(spacing: 8) {
                    Button {
                        archive()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .buttonStyle(.shadcn(.outline, fillWidth: true))
                    Button(action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.shadcn(.outline, fillWidth: true))
                }
            } else {
                HStack(spacing: 8) {
                    Button {
                        reopenReminder()
                    } label: {
                        Label("Move to In progress", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.shadcn(.secondary, fillWidth: true))
                    Button(action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.shadcn(.outline, fillWidth: true))
                }
            }
        }
    }

    private var infoGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let app = reminder.sourceApp { appRow("App", app) }
            if let title = reminder.windowTitle { row("Window", title) }
            if let url = reminder.url { urlRow("URL", url) }
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

    private func appRow(_ label: String, _ appName: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(appName)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { openApp(appName) }
                .pointingHandOnHover()
                .help("Open \(appName)")
        }
    }

    private func openApp(_ name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", name]
        try? process.run()
    }

    private func urlRow(_ label: String, _ url: URL) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(url.absoluteString)
                .font(.caption)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { NSWorkspace.shared.open(url) }
                .pointingHandOnHover()
                .help("Open in browser")
        }
    }

    /// Reschedule editor — the same schedule picker used when creating a
    /// reminder, presented in a popover with a confirm action.
    private var reschedulePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remind me later")
                .font(.headline)
            SchedulePickerView(scheduleKind: $editScheduleKind,
                               relativeMinutes: $editRelativeMinutes,
                               absoluteDate: $editAbsoluteDate)
            HStack {
                Button("Cancel") { showReschedule = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.shadcn(.outline))
                Spacer()
                Button("Update") { applyReschedule() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.shadcn(.primary))
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    /// Seed the editor with fresh create-flow defaults (In 1 hour) each time it
    /// opens, matching the reminder-creation experience.
    private func startReschedule() {
        editScheduleKind = .relative
        editRelativeMinutes = 60
        editAbsoluteDate = Date().addingTimeInterval(3600)
        showReschedule = true
    }

    /// "Remind later" is just rescheduling: resolve the picked schedule into a
    /// fire date and re-arm the notification. The reminder stays `inProgress`.
    private func applyReschedule() {
        let fireDate: Date
        switch editScheduleKind {
        case .relative:
            fireDate = Date().addingTimeInterval(TimeInterval(max(1, editRelativeMinutes) * 60))
        case .absolute:
            fireDate = editAbsoluteDate
        }
        reminder.scheduleKind = editScheduleKind
        reminder.fireDate = fireDate
        reminder.status = .inProgress
        try? context.save()
        NotificationScheduler.cancel(reminder)
        NotificationScheduler.schedule(reminder)
        showReschedule = false
    }

    private func markCompleted() {
        reminder.status = .completed
        try? context.save()
        NotificationScheduler.cancel(reminder)
    }

    private func archive() {
        reminder.status = .archived
        try? context.save()
        NotificationScheduler.cancel(reminder)
    }

    /// Move an archived/completed reminder back to In progress and, if its fire
    /// date is still in the future, re-arm the notification.
    private func reopenReminder() {
        reminder.status = .inProgress
        try? context.save()
        NotificationScheduler.cancel(reminder)
        if reminder.fireDate > Date() {
            NotificationScheduler.schedule(reminder)
        }
    }
}

private extension View {
    /// Shows a pointing-hand (finger) cursor while hovering, hinting that the
    /// view is clickable without changing its appearance.
    func pointingHandOnHover() -> some View {
        onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
