import SwiftUI

// MARK: - Livestock Detail View

/// Detail view for a single livestock item with health timeline.
/// New Brutalist design: sharp corners, bold borders, high contrast.
struct LivestockDetailView: View {

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var livestock: Livestock
    @State private var healthLogs: [LivestockLog] = []
    @State private var isEditing = false
    @State private var showingHealthLogSheet = false
    @State private var showingDeleteConfirmation = false

    // MARK: - Initialization

    init(livestock: Livestock) {
        _livestock = State(initialValue: livestock)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Large Photo
                    photoSection

                    // Info Cards
                    VStack(spacing: BrutalistTheme.Spacing.md) {
                        // Species Info Card
                        speciesInfoCard

                        // Health Status Card
                        healthStatusCard

                        // Purchase Info Card
                        purchaseInfoCard

                        // Notes Section
                        notesSection

                        // Health Log Timeline
                        healthLogTimeline
                    }
                    .padding(BrutalistTheme.Spacing.lg)
                }
            }
            .background(BrutalistTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(BrutalistTheme.Typography.button)
                    .foregroundStyle(BrutalistTheme.Colors.text)
                }

                ToolbarItem(placement: .principal) {
                    Text(livestock.name.uppercased())
                        .font(BrutalistTheme.Typography.headerSmall)
                        .foregroundStyle(BrutalistTheme.Colors.text)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { isEditing = true }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(BrutalistTheme.Colors.text)
                    }
                }
            }
            .sheet(isPresented: $showingHealthLogSheet) {
                AddHealthLogSheet(livestock: livestock) { newLog in
                    Task {
                        // addLivestockLog also updates the livestock's health status; refresh this view's copy
                        // from app state instead of pushing a stale one back to the server.
                        await appState.addLivestockLog(newLog)
                        loadHealthLogs()
                        if let refreshed = appState.livestock.first(where: { $0.id == livestock.id }) {
                            livestock = refreshed
                        }
                    }
                }
            }
            .alert("Delete Livestock?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await appState.deleteLivestock(livestock)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(livestock.name)\"? This action cannot be undone.")
            }
            .onAppear {
                loadHealthLogs()
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        ZStack(alignment: .bottomTrailing) {
            if let photoData = livestock.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 280)
                    .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(BrutalistTheme.Colors.text.opacity(0.1))
                        .frame(height: 280)

                    VStack(spacing: BrutalistTheme.Spacing.md) {
                        Image(systemName: livestock.category.icon)
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.3))

                        Text("NO PHOTO")
                            .font(BrutalistTheme.Typography.caption)
                            .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.3))
                    }
                }
            }

            // Category badge overlay
            HStack(spacing: BrutalistTheme.Spacing.xs) {
                Image(systemName: livestock.category.icon)
                    .font(.system(size: 14, weight: .bold))

                Text(livestock.category.displayName.uppercased())
                    .font(BrutalistTheme.Typography.button)
            }
            .foregroundStyle(BrutalistTheme.Colors.text)
            .padding(.horizontal, BrutalistTheme.Spacing.md)
            .padding(.vertical, BrutalistTheme.Spacing.sm)
            .background(BrutalistTheme.Colors.action)
            .brutalistBorder()
            .padding(BrutalistTheme.Spacing.md)
        }
        .overlay(
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: BrutalistTheme.Borders.heavy),
            alignment: .bottom
        )
    }

    // MARK: - Species Info Card

    private var speciesInfoCard: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("SPECIES INFO")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(BrutalistTheme.Colors.text)

            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: 1)

            // Common name
            infoRow(label: "Common Name", value: livestock.name)

            // Scientific name
            if let scientificName = livestock.scientificName {
                infoRow(label: "Scientific Name", value: scientificName, isItalic: true)
            }

            // Category
            infoRow(label: "Category", value: livestock.category.displayName)

            // Quantity
            infoRow(label: "Quantity", value: "\(livestock.quantity)")
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistCard()
    }

    // MARK: - Health Status Card

    private var healthStatusCard: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("HEALTH STATUS")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)

                Spacer()

                // Update health button
                Button(action: { showingHealthLogSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("LOG")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(BrutalistTheme.Colors.text)
                    .padding(.horizontal, BrutalistTheme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(BrutalistTheme.Colors.action)
                    .brutalistBorder(width: 2)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(BrutalistTheme.Colors.text)

            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: 1)

            // Status display
            HStack(spacing: BrutalistTheme.Spacing.md) {
                Image(systemName: livestock.healthStatus.icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(livestock.healthStatus.isWarning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.action)

                VStack(alignment: .leading, spacing: 2) {
                    Text(livestock.healthStatus.displayName)
                        .font(BrutalistTheme.Typography.headerMedium)
                        .foregroundStyle(livestock.healthStatus.isWarning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.text)

                    Text("Last updated: \(livestock.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
                }

                Spacer()
            }
            .padding(.vertical, BrutalistTheme.Spacing.sm)
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistCard()
    }

    // MARK: - Purchase Info Card

    private var purchaseInfoCard: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "cart.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("PURCHASE INFO")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(BrutalistTheme.Colors.text)

            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: 1)

            // Purchase date
            infoRow(label: "Purchase Date", value: formatDate(livestock.purchaseDate))

            // Days owned
            infoRow(label: "Days Owned", value: "\(daysOwned)")

            // Price
            if let price = livestock.purchasePrice {
                infoRow(label: "Purchase Price", value: formatCurrency(price))
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistCard()
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        if let notes = livestock.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                // Header
                HStack {
                    Image(systemName: "note.text")
                        .font(.system(size: 16, weight: .bold))
                    Text("NOTES")
                        .font(BrutalistTheme.Typography.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(BrutalistTheme.Colors.text)

                Rectangle()
                    .fill(BrutalistTheme.Colors.text)
                    .frame(height: 1)

                Text(notes)
                    .font(BrutalistTheme.Typography.body)
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.8))
            }
            .padding(BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.cardBackground)
            .brutalistCard()
        }
    }

    // MARK: - Health Log Timeline

    private var healthLogTimeline: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("HEALTH LOG TIMELINE")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)

                Spacer()

                Text("\(healthLogs.count) ENTRIES")
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
            }
            .foregroundStyle(BrutalistTheme.Colors.text)

            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: 1)

            if healthLogs.isEmpty {
                VStack(spacing: BrutalistTheme.Spacing.sm) {
                    Text("No health logs yet")
                        .font(BrutalistTheme.Typography.body)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.5))

                    BrutalistButton.secondary("Add First Log") {
                        showingHealthLogSheet = true
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BrutalistTheme.Spacing.lg)
            } else {
                ForEach(healthLogs) { log in
                    healthLogEntry(log)
                }
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.cardBackground)
        .brutalistCard()
    }

    private func healthLogEntry(_ log: LivestockLog) -> some View {
        HStack(alignment: .top, spacing: BrutalistTheme.Spacing.md) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(log.healthStatus.isWarning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.action)
                    .frame(width: 12, height: 12)

                Rectangle()
                    .fill(BrutalistTheme.Colors.text.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)

            // Entry content
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                HStack {
                    Text(log.healthStatus.displayName)
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundStyle(log.healthStatus.isWarning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.text)

                    Spacer()

                    Text(formatDate(log.loggedAt))
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.5))
                }

                if let notes = log.notes {
                    Text(notes)
                        .font(BrutalistTheme.Typography.body)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.7))
                }
            }
            .padding(.bottom, BrutalistTheme.Spacing.md)
        }
    }

    // MARK: - Helper Views

    private func infoRow(label: String, value: String, isItalic: Bool = false) -> some View {
        HStack {
            Text(label.uppercased())
                .font(BrutalistTheme.Typography.caption)
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))

            Spacer()

            Text(value)
                .font(BrutalistTheme.Typography.body)
                .foregroundStyle(BrutalistTheme.Colors.text)
                .italic(isItalic)
        }
    }

    // MARK: - Computed Properties

    private var daysOwned: Int {
        Calendar.current.dateComponents([.day], from: livestock.purchaseDate, to: Date()).day ?? 0
    }

    // MARK: - Helper Functions

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func loadHealthLogs() {
        // Load logs from storage via AppState
        healthLogs = appState.fetchLivestockLogs(for: livestock)
    }
}

// MARK: - Add Health Log Sheet

struct AddHealthLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let livestock: Livestock
    let onSave: (LivestockLog) -> Void

    @State private var selectedStatus: HealthStatus = .healthy
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: BrutalistTheme.Spacing.lg) {
                // Status Picker
                VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                    Text("HEALTH STATUS")
                        .font(BrutalistTheme.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(BrutalistTheme.Colors.text)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: BrutalistTheme.Spacing.sm) {
                        ForEach(HealthStatus.allCases) { status in
                            Button(action: { selectedStatus = status }) {
                                VStack(spacing: 4) {
                                    Image(systemName: status.icon)
                                        .font(.system(size: 24, weight: .bold))
                                    Text(status.displayName)
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundStyle(status.isWarning ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BrutalistTheme.Spacing.sm)
                                .background(selectedStatus == status ? BrutalistTheme.Colors.action.opacity(0.3) : BrutalistTheme.Colors.background)
                                .brutalistBorder(width: selectedStatus == status ? BrutalistTheme.Borders.standard : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Notes
                BrutalistTextArea(
                    "Observations, behavior, appearance...",
                    text: $notes,
                    label: "Notes (Optional)",
                    minHeight: 100
                )

                Spacer()

                // Save Button
                BrutalistButton.primary("SAVE LOG", isFullWidth: true) {
                    let newLog = LivestockLog(
                        livestockId: livestock.id,
                        healthStatus: selectedStatus,
                        notes: notes.isEmpty ? nil : notes
                    )
                    onSave(newLog)
                    dismiss()
                }
            }
            .padding(BrutalistTheme.Spacing.lg)
            .background(BrutalistTheme.Colors.background)
            .navigationTitle("LOG HEALTH")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(BrutalistTheme.Typography.button)
                    .foregroundStyle(BrutalistTheme.Colors.text)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Livestock Detail") {
    LivestockDetailView(livestock: Livestock.sample)
        .environment(AppState())
}

#Preview("Add Health Log") {
    AddHealthLogSheet(livestock: Livestock.sample) { _ in }
}
