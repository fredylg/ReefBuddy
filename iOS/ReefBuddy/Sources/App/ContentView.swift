import SwiftUI

// MARK: - Content View

/// Root view with tab navigation following New Brutalist design principles.
/// Sharp edges, bold typography, high contrast.
struct ContentView: View {

    // MARK: - State

    @EnvironmentObject private var appState: AppState
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
        VStack(spacing: 2) {
            Text("\(appState.freeAnalysesRemaining)")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(appState.freeAnalysesRemaining > 0 ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.warning)

            Text("FREE LEFT")
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
    case history
    case settings

    var title: String {
        switch self {
        case .tanks:
            return "TANKS"
        case .measure:
            return "MEASURE"
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
        case .history:
            return "chart.line.uptrend.xyaxis"
        case .settings:
            return "gearshape.fill"
        }
    }
}

// MARK: - Placeholder Views

/// Placeholder for settings - to be implemented
struct SettingsView: View {
    var body: some View {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))

            Text("SETTINGS")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text("App preferences and account")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrutalistTheme.Colors.background)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}
