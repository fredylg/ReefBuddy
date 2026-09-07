import SwiftUI

// MARK: - Content View

/// Root view with tab navigation following New Brutalist design principles.
/// Sharp edges, bold typography, high contrast.
struct ContentView: View {

    // MARK: - State

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager
    @State private var selectedTab: Tab = .tanks
    @State private var showingMaintenanceActions = false
    @State private var showingWaterChangeLog = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Tab Content
            tabContent
                .frame(maxHeight: .infinity)
        }
        .background(BrutalistTheme.Colors.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            brutalistTabBar
        }
        .onChange(of: appState.maintenanceDeepLink) { _, _ in
            handleMaintenanceDeepLinkIfPossible()
        }
        .sheet(isPresented: $showingMaintenanceActions) {
            MaintenanceQuickActionsSheet(
                deepLink: appState.maintenanceDeepLink,
                onClose: {
                    appState.maintenanceDeepLink = nil
                    showingMaintenanceActions = false
                },
                onGoToMeasure: {
                    selectedTab = .measure
                    showingMaintenanceActions = false
                },
                onLogWaterChange: {
                    showingMaintenanceActions = false
                    showingWaterChangeLog = true
                }
            )
        }
        .sheet(isPresented: $showingWaterChangeLog) {
            WaterChangeLogSheet(
                deepLink: appState.maintenanceDeepLink,
                onComplete: {
                    showingWaterChangeLog = false
                    appState.maintenanceDeepLink = nil
                },
                onCancel: {
                    showingWaterChangeLog = false
                }
            )
            .environmentObject(appState)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                Text("REEFBUDDY")
                    .font(BrutalistTheme.Typography.headerLarge)
                    .foregroundStyle(BrutalistTheme.Colors.text)

                Text(selectedTab.subtitle)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundStyle(subtitleColor)
            }

            Spacer()

            // Free tier indicator
            freeTierBadge
        }
        .padding(.horizontal, BrutalistTheme.Spacing.lg)
        .padding(.vertical, BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.background)
        .overlay(
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: BrutalistTheme.Borders.standard),
            alignment: .bottom
        )
    }

    private var freeTierBadge: some View {
        let credits = storeManager.totalCredits
        return VStack(spacing: 2) {
            Text("\(credits)")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundStyle(credits > 0 ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.warning)

            Text("CREDITS")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(BrutalistTheme.Colors.text)
        }
        .padding(.horizontal, BrutalistTheme.Spacing.sm)
        .padding(.vertical, BrutalistTheme.Spacing.xs)
        .background(BrutalistTheme.Colors.background)
        .brutalistBorder(width: 2)
    }
    
    /// Color for the subtitle text based on environment
    /// Black for production, green for local/other environments
    private var subtitleColor: Color {
        if APIClient.isUsingProduction() {
            // Production: black (with opacity)
            return BrutalistTheme.Colors.text.opacity(0.6)
        } else {
            // Local/other environment: green
            return Color.green
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .settings:
            NavigationStack { SettingsView() }

        case .tanks:
            TankListView()

        case .measure:
            if let tank = appState.selectedTank {
                MeasurementEntryView(tank: tank)
            } else {
                noTankSelectedView
            }

        case .livestock:
            if appState.selectedTank != nil {
                LivestockListView()
            } else {
                noTankSelectedView
            }

        case .history:
            if let tank = appState.selectedTank {
                HistoryView(tank: tank)
            } else {
                noTankSelectedView
            }

        }
    }

    private var noTankSelectedView: some View {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            Image(systemName: "drop.triangle")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.3))

            Text("NO TANK SELECTED")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundStyle(BrutalistTheme.Colors.text)

            Text("Create or select a tank first")
                .font(BrutalistTheme.Typography.body)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))

            BrutalistButton.primary("GO TO TANKS") {
                selectedTab = .tanks
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrutalistTheme.Colors.background)
    }

    // MARK: - Tab Bar

    private var brutalistTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.vertical, 8)
        .background(
            BrutalistTheme.Colors.background
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: BrutalistTheme.Borders.heavy),
            alignment: .top
        )
    }

    private func tabButton(for tab: Tab) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(selectedTab == tab ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(selectedTab == tab ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.45))
                }

                Text(tab.title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(selectedTab == tab ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Maintenance Quick Actions

private extension ContentView {
    func handleMaintenanceDeepLinkIfPossible() {
        guard let link = appState.maintenanceDeepLink else { return }
        if let tank = appState.tanks.first(where: { $0.id == link.tankId }) {
            appState.selectTank(tank)
        }
        // Bring user into tank context and show actions; a sheet already up would block the new one.
        selectedTab = .measure
        showingWaterChangeLog = false
        showingMaintenanceActions = true
    }
}

private struct MaintenanceQuickActionsSheet: View {
    let deepLink: MaintenanceDeepLink?
    let onClose: () -> Void
    let onGoToMeasure: () -> Void
    let onLogWaterChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.lg) {
            HStack {
                Text("MAINTENANCE")
                    .font(BrutalistTheme.Typography.headerMedium)
                    .foregroundStyle(BrutalistTheme.Colors.text)
                Spacer()
                Button("CLOSE") { onClose() }
                    .font(BrutalistTheme.Typography.button)
                    .foregroundStyle(BrutalistTheme.Colors.text)
            }

            Text(subtitle)
                .font(BrutalistTheme.Typography.body)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.7))

            BrutalistButton.primary(primaryActionTitle, isFullWidth: true) {
                onGoToMeasure()
            }

            BrutalistButton.secondary("RUN AI ANALYSIS", isFullWidth: true) {
                onGoToMeasure()
            }

            BrutalistButton.secondary("LOG WATER CHANGE", isFullWidth: true) {
                onLogWaterChange()
            }
        }
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.background)
    }

    private var subtitle: String {
        guard let deepLink else { return "Quick actions for your reminder." }
        switch deepLink.type {
        case .testing:
            return "Time to test your water."
        case .waterChange:
            return "Time for a water change."
        case .filter:
            return "Time to service your filter."
        }
    }

    private var primaryActionTitle: String {
        guard let deepLink else { return "OPEN TANK" }
        switch deepLink.type {
        case .testing:
            return "ENTER TEST RESULTS"
        case .waterChange:
            return "OPEN TANK"
        case .filter:
            return "OPEN TANK"
        }
    }
}

struct WaterChangeLogSheet: View {
    let deepLink: MaintenanceDeepLink?
    var fallbackTank: Tank? = nil
    let onComplete: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var performedAt = Date()
    @State private var percentReplaced = ""
    @State private var gallonsReplaced = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingHistory = false

    private var tank: Tank? {
        if let tankId = deepLink?.tankId {
            return appState.tanks.first(where: { $0.id == tankId }) ?? fallbackTank ?? appState.selectedTank
        }
        return fallbackTank ?? appState.selectedTank
    }

    private var canSave: Bool {
        Double(percentReplaced.trimmingCharacters(in: .whitespaces)) != nil ||
        Double(gallonsReplaced.trimmingCharacters(in: .whitespaces)) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.lg) {
                    Text("LOG WATER CHANGE")
                        .font(BrutalistTheme.Typography.headerMedium)
                        .foregroundStyle(BrutalistTheme.Colors.text)

                    Text(tank?.name.uppercased() ?? "SELECTED TANK")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.65))

                    BrutalistButton.secondary("VIEW WATER CHANGE HISTORY", isFullWidth: true) {
                        showingHistory = true
                    }

                    DatePicker("WHEN", selection: $performedAt, displayedComponents: [.date, .hourAndMinute])
                        .font(BrutalistTheme.Typography.body)
                        .padding(BrutalistTheme.Spacing.md)
                        .background(BrutalistTheme.Colors.background)
                        .brutalistBorder()

                    BrutalistTextField(
                        "10",
                        text: $percentReplaced,
                        label: "PERCENT REPLACED",
                        helperText: "Optional if gallons are entered.",
                        keyboardType: .decimalPad
                    )

                    BrutalistTextField(
                        "5",
                        text: $gallonsReplaced,
                        label: "GALLONS REPLACED",
                        helperText: "Optional if percent is entered.",
                        keyboardType: .decimalPad
                    )

                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                        Text("NOTES")
                            .font(BrutalistTheme.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(BrutalistTheme.Colors.text)
                        TextEditor(text: $notes)
                            .frame(minHeight: 110)
                            .padding(BrutalistTheme.Spacing.sm)
                            .background(BrutalistTheme.Colors.background)
                            .brutalistBorder()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BrutalistTheme.Typography.caption)
                            .foregroundStyle(BrutalistTheme.Colors.warning)
                    }

                    BrutalistButton.primary(isSaving ? "SAVING..." : "SAVE WATER CHANGE", isFullWidth: true) {
                        save()
                    }
                    .disabled(isSaving || !canSave)

                    BrutalistButton.secondary("CANCEL", isFullWidth: true) {
                        onCancel()
                    }
                }
                .padding(BrutalistTheme.Spacing.lg)
            }
            .background(BrutalistTheme.Colors.background)
        }
        .task {
            if let tank {
                await appState.fetchWaterChanges(for: tank)
            }
        }
        .sheet(isPresented: $showingHistory) {
            WaterChangeHistorySheet(
                tank: tank,
                onClose: { showingHistory = false }
            )
            .environmentObject(appState)
        }
    }

    private func save() {
        guard let tank else {
            errorMessage = "No tank selected."
            return
        }
        let percent = Double(percentReplaced.trimmingCharacters(in: .whitespaces))
        let gallons = Double(gallonsReplaced.trimmingCharacters(in: .whitespaces))
        guard percent != nil || gallons != nil else {
            errorMessage = "Enter percent or gallons replaced."
            return
        }

        isSaving = true
        errorMessage = nil

        let waterChange = WaterChange(
            tankId: tank.id,
            performedAt: performedAt,
            percentReplaced: percent,
            gallonsReplaced: gallons,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            sourceScheduleId: deepLink?.scheduleId
        )

        Task {
            _ = await appState.logWaterChange(waterChange)
            await MainActor.run {
                isSaving = false
                onComplete()
            }
        }
    }
}

private struct WaterChangeHistorySheet: View {
    let tank: Tank?
    let onClose: () -> Void

    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
                    HStack {
                        Text("WATER CHANGE HISTORY")
                            .font(BrutalistTheme.Typography.headerMedium)
                            .foregroundStyle(BrutalistTheme.Colors.text)
                        Spacer()
                        Button("CLOSE") { onClose() }
                            .font(BrutalistTheme.Typography.button)
                            .foregroundStyle(BrutalistTheme.Colors.text)
                    }

                    if let tank {
                        Text(tank.name.uppercased())
                            .font(BrutalistTheme.Typography.caption)
                            .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.65))

                        let items = appState.recentWaterChanges(for: tank.id)
                        if items.isEmpty {
                            Text("No water changes logged yet.")
                                .font(BrutalistTheme.Typography.body)
                                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.7))
                                .padding(.top, BrutalistTheme.Spacing.md)
                        } else {
                            ForEach(items) { wc in
                                waterChangeRow(wc)
                            }
                        }
                    } else {
                        Text("No tank selected.")
                            .font(BrutalistTheme.Typography.body)
                            .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.7))
                    }
                }
                .padding(BrutalistTheme.Spacing.lg)
            }
            .background(BrutalistTheme.Colors.background)
        }
    }

    private func waterChangeRow(_ wc: WaterChange) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            HStack {
                Text(formattedDate(wc.performedAt))
                    .font(BrutalistTheme.Typography.bodyBold)
                    .foregroundStyle(BrutalistTheme.Colors.text)
                Spacer()
                Text(amountText(wc))
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.7))
            }

            if let notes = wc.notes, !notes.isEmpty {
                Text(notes)
                    .font(BrutalistTheme.Typography.body)
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.85))
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard()
    }

    private func amountText(_ wc: WaterChange) -> String {
        if let pct = wc.percentReplaced {
            return String(format: "%.1f%%", pct)
        }
        if let gal = wc.gallonsReplaced {
            return String(format: "%.1f gal", gal)
        }
        return ""
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Tab Enum

enum Tab: CaseIterable {
    case settings
    case tanks
    case measure
    case livestock
    case history

    var title: String {
        switch self {
        case .settings:
            return "SETTINGS"
        case .tanks:
            return "TANKS"
        case .measure:
            return "MEASURE"
        case .livestock:
            return "LIVESTOCK"
        case .history:
            return "HISTORY"
        }
    }

    var subtitle: String {
        switch self {
        case .settings:
            return "App preferences"
        case .tanks:
            return "Manage your aquariums"
        case .measure:
            return "Log water parameters"
        case .livestock:
            return "Track your corals & fish"
        case .history:
            return "Track your progress"
        }
    }

    var icon: String {
        switch self {
        case .settings:
            return "gearshape.fill"
        case .tanks:
            return "drop.fill"
        case .measure:
            return "pencil.and.list.clipboard"
        case .livestock:
            return "fish.fill"
        case .history:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Settings View

/// Settings view with notification configuration and app preferences.
/// New Brutalist design: sharp corners, bold borders, high contrast.
struct SettingsView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var analysisStorage: AnalysisStorage
    @State private var showingNotificationSettings = false
    @State private var showingSubscription = false
    @State private var showingExport = false
    @State private var showingSavedAnalyses = false

    var body: some View {
        ScrollView {
            VStack(spacing: BrutalistTheme.Spacing.md) {
                // Notifications Section - Hidden for now
                // settingsSection(title: "ALERTS", icon: "bell.fill") {
                //     settingsRow(
                //         icon: "bell.badge.fill",
                //         title: "Notification Settings",
                //         subtitle: "Configure parameter alerts"
                //     ) {
                //         showingNotificationSettings = true
                //     }
                // }

                // Account Section
                settingsSection(title: "ACCOUNT", icon: "person.fill") {
                    settingsRow(
                        icon: "crown.fill",
                        title: "Subscription",
                        subtitle: "Manage your plan"
                    ) {
                        showingSubscription = true
                    }
                }

                // Maintenance Section
                settingsSection(title: "MAINTENANCE", icon: "calendar.badge.checkmark") {
                    settingsNavigationRow(
                        icon: "calendar.badge.checkmark",
                        title: "Maintenance Schedules",
                        subtitle: "Local reminders on this device",
                        destination: MaintenanceSchedulesListView()
                    )
                }

                // Data Section
                settingsSection(title: "DATA", icon: "externaldrive.fill") {
                    settingsRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Saved Analyses",
                        subtitle: "\(analysisStorage.savedAnalyses.count) saved"
                    ) {
                        showingSavedAnalyses = true
                    }
                    
                    Rectangle()
                        .fill(BrutalistTheme.Colors.text.opacity(0.1))
                        .frame(height: 1)
                    
                    settingsRow(
                        icon: "square.and.arrow.up.fill",
                        title: "Export Data",
                        subtitle: "Export your measurements"
                    ) {
                        showingExport = true
                    }
                }

                // About Section
                settingsSection(title: "ABOUT", icon: "info.circle.fill") {
                    VStack(spacing: 0) {
                        aboutRow(label: "Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                        Rectangle()
                            .fill(BrutalistTheme.Colors.text.opacity(0.1))
                            .frame(height: 1)
                        aboutRow(label: "Build", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
                    }
                }

                // App info
                VStack(spacing: BrutalistTheme.Spacing.sm) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(BrutalistTheme.Colors.action)

                    Text("REEFBUDDY")
                        .font(BrutalistTheme.Typography.headerSmall)
                        .foregroundStyle(BrutalistTheme.Colors.text)

                    Text("Water chemistry for serious reefers")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
                }
                .padding(.vertical, BrutalistTheme.Spacing.xl)
            }
            .padding(BrutalistTheme.Spacing.lg)
        }
        .background(BrutalistTheme.Colors.background)
        .sheet(isPresented: $showingNotificationSettings) {
            NavigationStack {
                NotificationSettingsView()
                    .navigationTitle("NOTIFICATIONS")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") {
                                showingNotificationSettings = false
                            }
                            .font(BrutalistTheme.Typography.button)
                            .foregroundStyle(BrutalistTheme.Colors.text)
                        }
                    }
            }
        }
        .sheet(isPresented: $showingSubscription) {
            PurchaseCreditsView()
        }
        .sheet(isPresented: $showingExport) {
            if let tank = appState.selectedTank {
                ExportView(tank: tank, measurements: appState.measurements)
            }
        }
        .sheet(isPresented: $showingSavedAnalyses) {
            NavigationStack {
                SavedAnalysesView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") {
                                showingSavedAnalyses = false
                            }
                            .font(BrutalistTheme.Typography.button)
                            .foregroundStyle(BrutalistTheme.Colors.text)
                        }
                    }
            }
        }
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(BrutalistTheme.Colors.text)

            content()
                .background(BrutalistTheme.Colors.cardBackground)
                .brutalistCard()
        }
    }

    private func settingsRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: BrutalistTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BrutalistTheme.Colors.action)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundStyle(BrutalistTheme.Colors.text)

                    Text(subtitle)
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.4))
            }
            .padding(BrutalistTheme.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private func settingsNavigationRow<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: BrutalistTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BrutalistTheme.Colors.action)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundStyle(BrutalistTheme.Colors.text)

                    Text(subtitle)
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.4))
            }
            .padding(BrutalistTheme.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(BrutalistTheme.Typography.body)
                .foregroundStyle(BrutalistTheme.Colors.text)

            Spacer()

            Text(value)
                .font(BrutalistTheme.Typography.body)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .padding(BrutalistTheme.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(StoreManager())
        .environmentObject(AnalysisStorage())
        .environmentObject(MaintenanceScheduleStore())
}
