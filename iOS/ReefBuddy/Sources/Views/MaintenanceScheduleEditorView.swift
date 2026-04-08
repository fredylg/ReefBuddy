import SwiftUI
import UserNotifications

// MARK: - Add/Edit Maintenance Schedule

struct MaintenanceScheduleEditorView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var scheduleStore: MaintenanceScheduleStore
    @Environment(\.dismiss) private var dismiss

    private let existing: MaintenanceSchedule?

    @State private var type: MaintenanceSchedule.ScheduleType = .waterChange
    @State private var tankId: UUID?
    @State private var kind: MaintenanceSchedule.ScheduleKind = .intervalDays
    @State private var intervalDays: Int = 7
    @State private var selectedWeekdays: Set<Int> = [1]
    @State private var time: Date = Date()
    @State private var testingChecklist: Set<MaintenanceChecklistItem> = []

    @State private var showingPermissionSheet = false
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingDeniedAlert = false
    @State private var pendingSave = false

    init(existing: MaintenanceSchedule?) {
        self.existing = existing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: BrutalistTheme.Spacing.lg) {
                typeTabs
                tankPicker
                frequencySection
                timeSection
                if type == .testing {
                    testingChecklistSection
                }

                BrutalistButton.primary("SAVE SCHEDULE", isFullWidth: true, isEnabled: isValid) {
                    Task { await saveTapped() }
                }

                if existing != nil {
                    BrutalistButton.destructive("DELETE SCHEDULE", isFullWidth: true) {
                        if let id = existing?.id {
                            scheduleStore.markDeleted(id)
                            Task { await MaintenanceNotificationService.shared.deleteSchedule(scheduleId: id) }
                            Task { await scheduleStore.syncPendingBestEffort() }
                        }
                        dismiss()
                    }
                }
            }
            .padding(BrutalistTheme.Spacing.lg)
        }
        .background(BrutalistTheme.Colors.background)
        .navigationTitle(existing == nil ? "ADD SCHEDULE" : "EDIT SCHEDULE")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("CANCEL") { dismiss() }
                    .font(BrutalistTheme.Typography.button)
                    .foregroundColor(BrutalistTheme.Colors.text)
            }
        }
        .onAppear {
            seedFromExisting()
            Task { permissionStatus = await MaintenanceNotificationService.shared.getAuthorizationStatus() }
        }
        .sheet(isPresented: $showingPermissionSheet) {
            enableRemindersSheet
        }
        .alert("NOTIFICATIONS OFF", isPresented: $showingDeniedAlert) {
            Button("OK", role: .cancel) {}
            Button("OPEN SETTINGS") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("The schedule was saved, but reminders won’t fire until you enable notifications in Settings.")
        }
    }

    private var isValid: Bool {
        guard tankId != nil else { return false }
        switch kind {
        case .intervalDays:
            return intervalDays >= 1
        case .weekly:
            return !selectedWeekdays.isEmpty
        }
    }

    // MARK: - UI blocks

    private var typeTabs: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            Text("TYPE")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)

            HStack(spacing: 0) {
                ForEach(MaintenanceSchedule.ScheduleType.allCases, id: \.self) { t in
                    Button(action: { type = t }) {
                        Text(t.badgeText)
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(BrutalistTheme.Colors.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(type == t ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
                            .brutalistBorder(width: 2, color: BrutalistTheme.Colors.text)
                    }
                    .buttonStyle(.plain)
                }
            }
            .brutalistCard(borderWidth: BrutalistTheme.Borders.standard)
        }
    }

    private var tankPicker: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            Text("TANK")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)

            HStack {
                Text(selectedTankName.uppercased())
                    .font(BrutalistTheme.Typography.bodyBold)
                    .foregroundColor(BrutalistTheme.Colors.text)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
            }
            .padding(BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.background)
            .brutalistCard()
            .overlay(
                Picker("", selection: Binding(
                    get: { tankId ?? appState.selectedTank?.id ?? appState.tanks.first?.id },
                    set: { tankId = $0 }
                )) {
                    ForEach(appState.tanks) { tank in
                        Text(tank.name).tag(Optional(tank.id))
                    }
                }
                .pickerStyle(.menu)
                .opacity(0.02)
            )
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            Text("FREQUENCY")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)

            VStack(spacing: BrutalistTheme.Spacing.sm) {
                frequencySelector(
                    title: "EVERY N DAYS",
                    isSelected: kind == .intervalDays,
                    action: { kind = .intervalDays }
                )

                if kind == .intervalDays {
                    intervalStepper
                }

                frequencySelector(
                    title: "WEEKLY",
                    isSelected: kind == .weekly,
                    action: { kind = .weekly }
                )

                if kind == .weekly {
                    weekdayChips
                }
            }
            .padding(BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.background)
            .brutalistCard()
        }
    }

    private func frequencySelector(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(BrutalistTheme.Colors.text)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(BrutalistTheme.Colors.text)
                }
            }
            .padding(BrutalistTheme.Spacing.sm)
            .background(isSelected ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
            .brutalistBorder(width: 2)
        }
        .buttonStyle(.plain)
    }

    private var intervalStepper: some View {
        HStack(spacing: BrutalistTheme.Spacing.md) {
            squareButton(system: "minus") { intervalDays = max(1, intervalDays - 1) }
            Text("\(intervalDays)")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.text)
                .frame(minWidth: 60)
            squareButton(system: "plus") { intervalDays += 1 }
            Spacer()
            Text("DAYS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .padding(.top, 4)
    }

    private func squareButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(BrutalistTheme.Colors.text)
                .frame(width: 44, height: 36)
                .background(BrutalistTheme.Colors.background)
                .brutalistBorder(width: 2)
        }
        .buttonStyle(.plain)
    }

    private var weekdayChips: some View {
        let labels = [(1, "MON"), (2, "TUE"), (3, "WED"), (4, "THU"), (5, "FRI"), (6, "SAT"), (7, "SUN")]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BrutalistTheme.Spacing.sm), count: 4), spacing: BrutalistTheme.Spacing.sm) {
            ForEach(labels, id: \.0) { iso, text in
                chip(text: text, isSelected: selectedWeekdays.contains(iso)) {
                    if selectedWeekdays.contains(iso) { selectedWeekdays.remove(iso) }
                    else { selectedWeekdays.insert(iso) }
                }
            }
        }
        .padding(.top, 6)
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            Text("TIME")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)

            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                Text(displayTime(time))
                    .font(BrutalistTheme.Typography.headerMedium)
                    .foregroundColor(BrutalistTheme.Colors.text)

                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
            }
            .padding(BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.background)
            .brutalistCard()
        }
    }

    private var testingChecklistSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            Text("TESTING CHECKLIST")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BrutalistTheme.Spacing.sm), count: 4), spacing: BrutalistTheme.Spacing.sm) {
                ForEach(MaintenanceChecklistItem.allCases, id: \.self) { item in
                    chip(text: item.rawValue, isSelected: testingChecklist.contains(item)) {
                        if testingChecklist.contains(item) { testingChecklist.remove(item) }
                        else { testingChecklist.insert(item) }
                    }
                }
            }
            .padding(BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.background)
            .brutalistCard()
        }
    }

    private func chip(text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(isSelected ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
                .brutalistBorder(width: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Permission sheet

    private var enableRemindersSheet: some View {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            Text("ENABLE REMINDERS")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text("ReefBuddy uses notifications to remind you about maintenance.")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.7))
                .multilineTextAlignment(.center)

            BrutalistButton.primary("ALLOW NOTIFICATIONS", isFullWidth: true) {
                Task {
                    let granted = await MaintenanceNotificationService.shared.requestAuthorizationIfNeeded()
                    permissionStatus = await MaintenanceNotificationService.shared.getAuthorizationStatus()
                    showingPermissionSheet = false
                    if pendingSave {
                        await finalizeSave(scheduleNotifications: granted && permissionStatus != .denied)
                    }
                }
            }

            BrutalistButton.secondary("NOT NOW", isFullWidth: true) {
                Task {
                    showingPermissionSheet = false
                    if pendingSave {
                        await finalizeSave(scheduleNotifications: false)
                    }
                }
            }
        }
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.background)
    }

    // MARK: - Save

    private func saveTapped() async {
        permissionStatus = await MaintenanceNotificationService.shared.getAuthorizationStatus()
        if permissionStatus == .notDetermined {
            pendingSave = true
            showingPermissionSheet = true
            return
        }

        await finalizeSave(scheduleNotifications: permissionStatus != .denied)
    }

    private func finalizeSave(scheduleNotifications: Bool) async {
        pendingSave = false
        let saved = buildSchedule()
        scheduleStore.upsertLocal(saved)

        if scheduleNotifications {
            await MaintenanceNotificationService.shared.upsertSchedule(saved)
        } else if permissionStatus == .denied {
            showingDeniedAlert = true
        }

        await scheduleStore.syncPendingBestEffort()
        dismiss()
    }

    private func buildSchedule() -> MaintenanceSchedule {
        let tz = TimeZone.current.identifier
        let tank = tankId ?? appState.selectedTank?.id ?? appState.tanks.first?.id ?? UUID()
        let timeLocal = toTimeLocal(time)

        let notes: String?
        if type == .testing {
            notes = MaintenanceSchedule.notesJSON(for: testingChecklist)
        } else {
            notes = nil
        }

        if var existing {
            existing.tankId = tank
            existing.type = type
            existing.scheduleKind = kind
            existing.intervalDays = kind == .intervalDays ? intervalDays : nil
            existing.weekdays = kind == .weekly ? Array(selectedWeekdays).sorted() : nil
            existing.timeLocal = timeLocal
            existing.timezone = tz
            existing.notes = notes
            existing.enabled = true
            existing.needsSync = true
            existing.updatedAt = Date()
            return existing
        }

        return MaintenanceSchedule(
            tankId: tank,
            type: type,
            enabled: true,
            scheduleKind: kind,
            intervalDays: kind == .intervalDays ? intervalDays : nil,
            weekdays: kind == .weekly ? Array(selectedWeekdays).sorted() : nil,
            timeLocal: timeLocal,
            timezone: tz,
            notes: notes
        )
    }

    // MARK: - Seeding

    private func seedFromExisting() {
        if let existing {
            type = existing.type
            tankId = existing.tankId
            kind = existing.scheduleKind
            intervalDays = existing.intervalDays ?? 7
            selectedWeekdays = Set(existing.weekdays ?? [])
            time = fromTimeLocal(existing.timeLocal) ?? Date()
            testingChecklist = existing.checklistItemsFromNotes()
        } else {
            tankId = appState.selectedTank?.id ?? appState.tanks.first?.id
            selectedWeekdays = [1]
        }
    }

    // MARK: - Time formatting

    private func toTimeLocal(_ date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 9
        let m = comps.minute ?? 0
        return String(format: "%02d:%02d", h, m)
    }

    private func fromTimeLocal(_ value: String) -> Date? {
        let parts = value.split(separator: ":").map(String.init)
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = h
        comps.minute = m
        return Calendar.current.date(from: comps)
    }

    private func displayTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    private var selectedTankName: String {
        let id = tankId ?? appState.selectedTank?.id ?? appState.tanks.first?.id
        return appState.tanks.first(where: { $0.id == id })?.name ?? "Select tank"
    }
}

