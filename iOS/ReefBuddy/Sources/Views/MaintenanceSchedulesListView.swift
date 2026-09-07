import SwiftUI
import UserNotifications

// MARK: - Maintenance Schedules List

struct MaintenanceSchedulesListView: View {
    @Environment(AppState.self) private var appState
    @Environment(MaintenanceScheduleStore.self) private var scheduleStore

    @State private var showingEditor = false
    @State private var editingSchedule: MaintenanceSchedule?
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.lg) {
                header

                if permissionStatus == .denied {
                    permissionWarning
                }

                BrutalistButton.primary("+ ADD SCHEDULE", isFullWidth: true) {
                    editingSchedule = nil
                    showingEditor = true
                }

                if scheduleStore.activeSchedules.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: BrutalistTheme.Spacing.md) {
                        ForEach(scheduleStore.activeSchedules) { schedule in
                            MaintenanceScheduleCard(
                                schedule: schedule,
                                tankName: appState.tanks.first(where: { $0.id == schedule.tankId })?.name ?? "Unknown",
                                onToggle: { enabled in
                                    scheduleStore.setEnabled(enabled, for: schedule.id)
                                    Task { await MaintenanceNotificationService.shared.upsertSchedule(scheduleStore.schedule(with: schedule.id) ?? schedule) }
                                    Task { await scheduleStore.syncPendingBestEffort() }
                                },
                                onEdit: {
                                    editingSchedule = schedule
                                    showingEditor = true
                                },
                                onDelete: {
                                    scheduleStore.markDeleted(schedule.id)
                                    Task { await MaintenanceNotificationService.shared.deleteSchedule(scheduleId: schedule.id) }
                                    Task { await scheduleStore.syncPendingBestEffort() }
                                }
                            )
                        }
                    }
                }
            }
            .padding(BrutalistTheme.Spacing.lg)
        }
        .background(BrutalistTheme.Colors.background)
        .navigationTitle("MAINTENANCE")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                MaintenanceScheduleEditorView(existing: editingSchedule)
            }
        }
        .task {
            permissionStatus = await MaintenanceNotificationService.shared.getAuthorizationStatus()
            await MaintenanceNotificationService.shared.scheduleAll(scheduleStore.activeSchedules)
            await scheduleStore.syncPendingBestEffort()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            Text("MAINTENANCE SCHEDULES")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundStyle(BrutalistTheme.Colors.text)

            Text("Reminders are scheduled on this device.")
                .font(BrutalistTheme.Typography.caption)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
        }
    }

    private var permissionWarning: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(BrutalistTheme.Colors.warning)
                Text("NOTIFICATIONS ARE OFF")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(BrutalistTheme.Colors.warning)
            }

            Rectangle()
                .fill(BrutalistTheme.Colors.warning)
                .frame(height: 1)

            Text("Turn on notifications in Settings to receive maintenance reminders.")
                .font(BrutalistTheme.Typography.body)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.8))

            BrutalistButton.secondary("OPEN SETTINGS", isFullWidth: true) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.warning.opacity(0.1))
        .brutalistCard(borderColor: BrutalistTheme.Colors.warning)
    }

    private var emptyState: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            Text("NO SCHEDULES YET")
                .font(BrutalistTheme.Typography.headerSmall)
                .foregroundStyle(BrutalistTheme.Colors.text)

            Text("Create reminders for water changes, filter service, or testing.")
                .font(BrutalistTheme.Typography.body)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
                .multilineTextAlignment(.center)

            BrutalistButton.primary("+ ADD SCHEDULE", isFullWidth: true) {
                editingSchedule = nil
                showingEditor = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard()
        .padding(.top, BrutalistTheme.Spacing.md)
    }
}

// MARK: - Card

private struct MaintenanceScheduleCard: View {
    let schedule: MaintenanceSchedule
    let tankName: String
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            HStack(alignment: .top) {
                typeBadge
                Spacer()
                brutalistToggle(isOn: .init(
                    get: { schedule.enabled },
                    set: { onToggle($0) }
                ))
            }

            Text(schedule.type.title)
                .font(BrutalistTheme.Typography.headerSmall)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(schedule.enabled ? 1 : 0.6))

            Text(summaryText)
                .font(BrutalistTheme.Typography.body)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(schedule.enabled ? 0.75 : 0.5))

            Text("Tank: \(tankName)")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(schedule.enabled ? 0.6 : 0.45))

            HStack(spacing: BrutalistTheme.Spacing.sm) {
                BrutalistButton.secondary("EDIT", isFullWidth: true) { onEdit() }
                BrutalistButton.destructive("DELETE", isFullWidth: true) { showingDeleteConfirm = true }
            }
        }
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard()
        .opacity(schedule.enabled ? 1 : 0.92)
        .alert("DELETE SCHEDULE", isPresented: $showingDeleteConfirm) {
            Button("CANCEL", role: .cancel) {}
            Button("DELETE", role: .destructive) { onDelete() }
        } message: {
            Text("This will remove the schedule and cancel its reminders on this device.")
        }
    }

    private var typeBadge: some View {
        Text(schedule.type.badgeText)
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(BrutalistTheme.Colors.text)
            .padding(.horizontal, BrutalistTheme.Spacing.sm)
            .padding(.vertical, 6)
            .background(BrutalistTheme.Colors.background)
            .brutalistBorder(width: 2)
    }

    private var summaryText: String {
        let time = formattedTime(schedule.timeLocal)
        switch schedule.scheduleKind {
        case .intervalDays:
            let d = schedule.intervalDays ?? 7
            return "Every \(d) days at \(time)"
        case .weekly:
            let days = (schedule.weekdays ?? []).map(weekdayLabel).joined(separator: " + ")
            return "\(days) at \(time)"
        }
    }

    private func weekdayLabel(_ iso: Int) -> String {
        let labels = ["MON","TUE","WED","THU","FRI","SAT","SUN"]
        guard iso >= 1 && iso <= 7 else { return "?" }
        return labels[iso - 1]
    }

    private func formattedTime(_ timeLocal: String) -> String {
        let parts = timeLocal.split(separator: ":").map(String.init)
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return timeLocal }
        var comps = DateComponents()
        comps.hour = h
        comps.minute = m
        let cal = Calendar.current
        let date = cal.date(from: comps) ?? Date()
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    private func brutalistToggle(isOn: Binding<Bool>) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.wrappedValue.toggle()
            }
        }) {
            ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                Rectangle()
                    .fill(isOn.wrappedValue ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text.opacity(0.2))
                    .frame(width: 52, height: 28)
                    .brutalistBorder(width: 2)

                Rectangle()
                    .fill(BrutalistTheme.Colors.background)
                    .frame(width: 22, height: 22)
                    .brutalistBorder(width: 2)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
    }
}

