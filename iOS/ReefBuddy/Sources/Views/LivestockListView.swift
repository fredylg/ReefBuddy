import SwiftUI

// MARK: - Livestock List View

/// Grid/list view displaying all livestock in the selected tank.
/// New Brutalist design: sharp corners, bold borders, high contrast.
struct LivestockListView: View {

    // MARK: - State

    @EnvironmentObject private var appState: AppState
    @State private var showingAddSheet = false
    @State private var selectedLivestock: Livestock?
    @State private var livestockToDelete: Livestock?
    @State private var showDeleteConfirmation = false
    @State private var displayMode: DisplayMode = .grid

    // MARK: - Display Mode

    enum DisplayMode: String, CaseIterable {
        case grid = "grid"
        case list = "list"

        var icon: String {
            switch self {
            case .grid:
                return "square.grid.2x2.fill"
            case .list:
                return "list.bullet"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Filter/Display Controls
                controlsHeader

                // Content
                if appState.livestock.isEmpty {
                    emptyStateView
                } else {
                    if displayMode == .grid {
                        gridView
                    } else {
                        listView
                    }
                }
            }

            // Floating Action Button
            addButton
        }
        .background(BrutalistTheme.Colors.background)
        .task {
            // Fetch livestock from backend on view appear (syncs with local storage)
            if let tank = appState.selectedTank {
                await appState.fetchLivestock(for: tank)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            if let tank = appState.selectedTank {
                AddLivestockView(tank: tank)
            }
        }
        .sheet(item: $selectedLivestock) { livestock in
            LivestockDetailView(livestock: livestock)
        }
        .alert("Delete Livestock?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                livestockToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let livestock = livestockToDelete {
                    deleteLivestock(livestock)
                }
            }
        } message: {
            if let livestock = livestockToDelete {
                Text("Are you sure you want to delete \"\(livestock.name)\"? This action cannot be undone.")
            }
        }
    }

    // MARK: - Controls Header

    private var controlsHeader: some View {
        HStack {
            // Category filter could go here in future
            Text("\(appState.livestock.count) ITEMS")
                .font(BrutalistTheme.Typography.caption)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))

            Spacer()

            // Display mode toggle
            HStack(spacing: 0) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayMode = mode
                        }
                    }) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(BrutalistTheme.Colors.text)
                            .frame(width: 36, height: 36)
                            .background(displayMode == mode ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
                    }
                    .buttonStyle(.plain)

                    if mode != DisplayMode.allCases.last {
                        Rectangle()
                            .fill(BrutalistTheme.Colors.text)
                            .frame(width: BrutalistTheme.Borders.light)
                    }
                }
            }
            .brutalistBorder(width: BrutalistTheme.Borders.light)
        }
        .padding(.horizontal, BrutalistTheme.Spacing.lg)
        .padding(.vertical, BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.background)
        .overlay(
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: BrutalistTheme.Borders.light),
            alignment: .bottom
        )
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: BrutalistTheme.Spacing.md),
                    GridItem(.flexible(), spacing: BrutalistTheme.Spacing.md)
                ],
                spacing: BrutalistTheme.Spacing.md
            ) {
                ForEach(appState.livestock) { livestock in
                    LivestockGridItem(livestock: livestock)
                        .onTapGesture {
                            selectedLivestock = livestock
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                livestockToDelete = livestock
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(BrutalistTheme.Spacing.lg)
            .padding(.bottom, 100) // Space for FAB
        }
    }

    // MARK: - List View

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(appState.livestock) { livestock in
                    LivestockListItem(livestock: livestock)
                        .onTapGesture {
                            selectedLivestock = livestock
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                livestockToDelete = livestock
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.bottom, 100) // Space for FAB
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "fish.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))

            Text("NO LIVESTOCK YET")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text("Add your first coral, fish, or invertebrate")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .multilineTextAlignment(.center)

            BrutalistButton.primary("ADD LIVESTOCK") {
                showingAddSheet = true
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrutalistTheme.Colors.background)
    }

    // MARK: - Add Button (FAB)

    private var addButton: some View {
        Button(action: {
            showingAddSheet = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text)
                .frame(width: 60, height: 60)
                .background(BrutalistTheme.Colors.action)
                .brutalistCard(
                    borderWidth: BrutalistTheme.Borders.heavy,
                    shadowOffset: BrutalistTheme.Shadows.offset
                )
        }
        .buttonStyle(.plain)
        .padding(.trailing, BrutalistTheme.Spacing.lg)
        .padding(.bottom, BrutalistTheme.Spacing.lg)
    }

    // MARK: - Actions

    private func deleteLivestock(_ livestock: Livestock) {
        Task {
            await appState.deleteLivestock(livestock)
        }
        livestockToDelete = nil
    }
}

// MARK: - Grid Item

/// Individual livestock card for grid display
struct LivestockGridItem: View {
    let livestock: Livestock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo or placeholder
            photoSection
                .frame(height: 120)
                .clipped()

            // Divider
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: BrutalistTheme.Borders.standard)

            // Info section
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                // Category badge
                categoryBadge

                // Name
                Text(livestock.name.uppercased())
                    .font(BrutalistTheme.Typography.bodyBold)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .lineLimit(1)

                // Quantity if > 1
                if livestock.quantity > 1 {
                    Text("QTY: \(livestock.quantity)")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                }

                // Health indicator
                healthIndicator
            }
            .padding(BrutalistTheme.Spacing.sm)
        }
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistCard(
            borderWidth: BrutalistTheme.Borders.standard,
            shadowOffset: BrutalistTheme.Shadows.offset
        )
    }

    private var photoSection: some View {
        Group {
            if let photoData = livestock.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle()
                        .fill(BrutalistTheme.Colors.text.opacity(0.1))

                    Image(systemName: livestock.category.icon)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))
                }
            }
        }
    }

    private var categoryBadge: some View {
        HStack(spacing: BrutalistTheme.Spacing.xs) {
            Image(systemName: livestock.category.icon)
                .font(.system(size: 10, weight: .bold))

            Text(livestock.category.displayName.uppercased())
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(BrutalistTheme.Colors.text)
        .padding(.horizontal, BrutalistTheme.Spacing.xs)
        .padding(.vertical, 2)
        .background(BrutalistTheme.Colors.action.opacity(0.3))
        .brutalistBorder(width: 1)
    }

    private var healthIndicator: some View {
        HStack(spacing: BrutalistTheme.Spacing.xs) {
            Circle()
                .fill(livestock.healthStatus.isWarning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.action)
                .frame(width: 8, height: 8)

            Text(livestock.healthStatus.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(livestock.healthStatus.isWarning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.text.opacity(0.8))
        }
    }
}

// MARK: - List Item

/// Individual livestock row for list display
struct LivestockListItem: View {
    let livestock: Livestock

    var body: some View {
        HStack(spacing: BrutalistTheme.Spacing.md) {
            // Photo thumbnail
            photoThumbnail

            // Info
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                // Name
                Text(livestock.name.uppercased())
                    .font(BrutalistTheme.Typography.bodyBold)
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .lineLimit(1)

                // Category and quantity
                HStack(spacing: BrutalistTheme.Spacing.sm) {
                    categoryBadge

                    if livestock.quantity > 1 {
                        Text("x\(livestock.quantity)")
                            .font(BrutalistTheme.Typography.caption)
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                    }
                }

                // Scientific name
                if let scientificName = livestock.scientificName {
                    Text(scientificName)
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                        .italic()
                        .lineLimit(1)
                }
            }

            Spacer()

            // Health status
            healthIndicator
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.cardBackground)
        .overlay(
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var photoThumbnail: some View {
        Group {
            if let photoData = livestock.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle()
                        .fill(BrutalistTheme.Colors.text.opacity(0.1))

                    Image(systemName: livestock.category.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))
                }
            }
        }
        .frame(width: 56, height: 56)
        .brutalistBorder(width: BrutalistTheme.Borders.light)
    }

    private var categoryBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: livestock.category.icon)
                .font(.system(size: 10, weight: .bold))

            Text(livestock.category.displayName.uppercased())
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(BrutalistTheme.Colors.text)
        .padding(.horizontal, BrutalistTheme.Spacing.xs)
        .padding(.vertical, 2)
        .background(BrutalistTheme.Colors.action.opacity(0.3))
        .brutalistBorder(width: 1)
    }

    private var healthIndicator: some View {
        VStack(spacing: 2) {
            Image(systemName: livestock.healthStatus.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(livestock.healthStatus.isWarning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.action)

            Text(livestock.healthStatus.displayName)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(livestock.healthStatus.isWarning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.text.opacity(0.6))
        }
        .frame(width: 60)
    }
}

// MARK: - Preview

#Preview("Livestock List - Grid") {
    LivestockListView()
        .environmentObject(AppState())
}

#Preview("Grid Item") {
    LivestockGridItem(livestock: Livestock.sample)
        .frame(width: 180)
        .padding()
        .background(BrutalistTheme.Colors.background)
}

#Preview("List Item") {
    LivestockListItem(livestock: Livestock.sample)
        .background(BrutalistTheme.Colors.background)
}
