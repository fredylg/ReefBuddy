import SwiftUI

// MARK: - Content View

/// Root view with tab navigation following New Brutalist design principles.
/// Sharp edges, bold typography, high contrast.
struct ContentView: View {

    // MARK: - State

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager
    @State private var selectedTab: Tab = .tanks

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            VStack(spacing: 0) {
                // Header
                headerView

                // Tab Content
                tabContent
                    .frame(maxHeight: .infinity)

                // Spacer for tab bar
                Color.clear
                    .frame(height: 80)
            }

            // Custom Tab Bar
            brutalistTabBar
        }
        .background(BrutalistTheme.Colors.background)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                Text("REEFBUDDY")
                    .font(BrutalistTheme.Typography.headerLarge)
                    .foregroundColor(BrutalistTheme.Colors.text)

                Text(selectedTab.subtitle)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
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
                .foregroundColor(credits > 0 ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.warning)

            Text("CREDITS")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text)
        }
        .padding(.horizontal, BrutalistTheme.Spacing.sm)
        .padding(.vertical, BrutalistTheme.Spacing.xs)
        .background(BrutalistTheme.Colors.background)
        .brutalistBorder(width: 2)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
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

        case .settings:
            SettingsView()
        }
    }

    private var noTankSelectedView: some View {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            Image(systemName: "drop.triangle")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))

            Text("NO TANK SELECTED")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text("Create or select a tank first")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))

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
        .background(BrutalistTheme.Colors.background)
        .overlay(
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: BrutalistTheme.Borders.heavy),
            alignment: .top
        )
        .padding(.bottom, 20) // Safe area padding
    }

    private func tabButton(for tab: Tab) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: BrutalistTheme.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: .bold))

                Text(tab.title)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(selectedTab == tab ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, BrutalistTheme.Spacing.md)
            .background(selectedTab == tab ? BrutalistTheme.Colors.action : Color.clear)
        }
    }
}

// MARK: - Tab Enum

enum Tab: CaseIterable {
    case tanks
    case measure
    case livestock
    case history
    case settings

    var title: String {
        switch self {
        case .tanks:
            return "TANKS"
        case .measure:
            return "MEASURE"
        case .livestock:
            return "LIVESTOCK"
        case .history:
            return "HISTORY"
        case .settings:
            return "SETTINGS"
        }
    }

    var subtitle: String {
        switch self {
        case .tanks:
            return "Manage your aquariums"
        case .measure:
            return "Log water parameters"
        case .livestock:
            return "Track your corals & fish"
        case .history:
            return "Track your progress"
        case .settings:
            return "App preferences"
        }
    }

    var icon: String {
        switch self {
        case .tanks:
            return "drop.fill"
        case .measure:
            return "pencil.and.list.clipboard"
        case .livestock:
            return "fish.fill"
        case .history:
            return "chart.line.uptrend.xyaxis"
        case .settings:
            return "gearshape.fill"
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
                        aboutRow(label: "Version", value: "1.0.2")
                        Rectangle()
                            .fill(BrutalistTheme.Colors.text.opacity(0.1))
                            .frame(height: 1)
                        aboutRow(label: "Build", value: "2026.02")
                    }
                }

                // App info
                VStack(spacing: BrutalistTheme.Spacing.sm) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.action)

                    Text("REEFBUDDY")
                        .font(BrutalistTheme.Typography.headerSmall)
                        .foregroundColor(BrutalistTheme.Colors.text)

                    Text("Water chemistry for serious reefers")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
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
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showingNotificationSettings = false
                            }
                            .font(BrutalistTheme.Typography.button)
                            .foregroundColor(BrutalistTheme.Colors.text)
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
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showingSavedAnalyses = false
                            }
                            .font(BrutalistTheme.Typography.button)
                            .foregroundColor(BrutalistTheme.Colors.text)
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
            .foregroundColor(BrutalistTheme.Colors.text)

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
                    .foregroundColor(BrutalistTheme.Colors.action)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundColor(BrutalistTheme.Colors.text)

                    Text(subtitle)
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))
            }
            .padding(BrutalistTheme.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text)

            Spacer()

            Text(value)
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .padding(BrutalistTheme.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}
