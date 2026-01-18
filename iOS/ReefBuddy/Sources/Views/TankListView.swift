import SwiftUI

// MARK: - Tank List View

/// Displays a list of user's aquarium tanks in New Brutalist style.
/// High-contrast cards with hard shadows and bold typography.
struct TankListView: View {

    // MARK: - State

    @EnvironmentObject private var appState: AppState
    @State private var showingAddTank = false
    @State private var tankToDelete: Tank?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: BrutalistTheme.Spacing.lg) {
                // Tank Cards
                ForEach(appState.tanks) { tank in
                    TankCard(
                        tank: tank,
                        isSelected: appState.selectedTank?.id == tank.id,
                        onSelect: {
                            appState.selectedTank = tank
                        },
                        onDelete: {
                            tankToDelete = tank
                        }
                    )
                }

                // Add Tank Button
                addTankButton

                // Empty State
                if appState.tanks.isEmpty {
                    emptyStateView
                }
            }
            .padding(BrutalistTheme.Spacing.lg)
        }
        .background(BrutalistTheme.Colors.background)
        .task {
            // Fetch tanks from backend on view appear (syncs with local storage)
            await appState.fetchTanks()
        }
        .sheet(isPresented: $showingAddTank) {
            AddTankSheet()
        }
        .alert("DELETE TANK", isPresented: .init(
            get: { tankToDelete != nil },
            set: { if !$0 { tankToDelete = nil } }
        )) {
            Button("CANCEL", role: .cancel) {
                tankToDelete = nil
            }
            Button("DELETE", role: .destructive) {
                if let tank = tankToDelete {
                    Task {
                        await appState.deleteTank(tank)
                    }
                }
                tankToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete \"\(tankToDelete?.name ?? "")\"? This action cannot be undone.")
        }
    }

    // MARK: - Add Tank Button

    private var addTankButton: some View {
        Button(action: { showingAddTank = true }) {
            HStack(spacing: BrutalistTheme.Spacing.md) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))

                Text("ADD NEW TANK")
                    .font(BrutalistTheme.Typography.button)
            }
            .foregroundColor(BrutalistTheme.Colors.text)
            .frame(maxWidth: .infinity)
            .padding(BrutalistTheme.Spacing.lg)
            .background(BrutalistTheme.Colors.background)
            .overlay(
                Rectangle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: BrutalistTheme.Borders.standard, dash: [10, 5])
                    )
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
            )
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            Image(systemName: "drop.triangle")
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.2))

            Text("NO TANKS YET")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text("Add your first aquarium to start tracking water parameters")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, BrutalistTheme.Spacing.xl)
    }
}

// MARK: - Tank Card

/// A single tank card in the list with brutalist styling
struct TankCard: View {
    let tank: Tank
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
                // Header Row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                        Text(tank.name.uppercased())
                            .font(BrutalistTheme.Typography.headerSmall)
                            .foregroundColor(BrutalistTheme.Colors.text)

                        Text(tank.tankType.displayName.uppercased())
                            .font(BrutalistTheme.Typography.caption)
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                    }

                    Spacer()

                    // Selected indicator
                    if isSelected {
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(BrutalistTheme.Colors.text)
                            .padding(.horizontal, BrutalistTheme.Spacing.sm)
                            .padding(.vertical, BrutalistTheme.Spacing.xs)
                            .background(BrutalistTheme.Colors.action)
                            .brutalistBorder(width: 2)
                    }
                }

                // Tank Details
                HStack(spacing: BrutalistTheme.Spacing.lg) {
                    detailItem(value: String(format: "%.0f", tank.volumeGallons), label: "GALLONS")

                    detailItem(value: formattedAge, label: "AGE")

                    Spacer()

                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(BrutalistTheme.Colors.warning)
                            .frame(width: 36, height: 36)
                            .background(BrutalistTheme.Colors.background)
                            .brutalistBorder(width: 2, color: BrutalistTheme.Colors.warning)
                    }
                }

                // Notes preview if available
                if let notes = tank.notes, !notes.isEmpty {
                    Text(notes)
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                        .lineLimit(2)
                        .padding(.top, BrutalistTheme.Spacing.xs)
                }
            }
            .padding(BrutalistTheme.Spacing.lg)
            .background(isSelected ? BrutalistTheme.Colors.action.opacity(0.1) : BrutalistTheme.Colors.background)
            .brutalistCard(
                borderWidth: isSelected ? BrutalistTheme.Borders.heavy : BrutalistTheme.Borders.standard,
                borderColor: isSelected ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text
            )
        }
        .buttonStyle(.plain)
    }

    private func detailItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
        }
    }

    private var formattedAge: String {
        let days = Calendar.current.dateComponents([.day], from: tank.createdAt, to: Date()).day ?? 0
        if days < 30 {
            return "\(days)D"
        } else if days < 365 {
            return "\(days / 30)M"
        } else {
            return "\(days / 365)Y"
        }
    }
}

// MARK: - Add Tank Sheet

/// Modal sheet for creating a new tank
struct AddTankSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var volumeText: String = ""
    @State private var selectedType: TankType = .mixedReef
    @State private var notes: String = ""

    private var isValid: Bool {
        !name.isEmpty && Double(volumeText) != nil && Double(volumeText)! > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrutalistTheme.Spacing.lg) {
                    // Tank Name
                    BrutalistTextField(
                        "Enter tank name",
                        text: $name,
                        label: "Tank Name",
                        helperText: "Give your aquarium a memorable name"
                    )

                    // Volume
                    BrutalistTextField(
                        "0",
                        text: $volumeText,
                        label: "Volume (Gallons)",
                        keyboardType: .decimalPad
                    )

                    // Tank Type
                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                        Text("TANK TYPE")
                            .font(BrutalistTheme.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(BrutalistTheme.Colors.text)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BrutalistTheme.Spacing.sm) {
                            ForEach(TankType.allCases, id: \.self) { type in
                                tankTypeButton(type)
                            }
                        }
                    }

                    // Notes
                    BrutalistTextArea(
                        "Optional notes about your tank...",
                        text: $notes,
                        label: "Notes",
                        minHeight: 80
                    )

                    // Save Button
                    BrutalistButton.primary("CREATE TANK", isFullWidth: true, isEnabled: isValid) {
                        createTank()
                    }
                    .padding(.top, BrutalistTheme.Spacing.md)
                }
                .padding(BrutalistTheme.Spacing.lg)
            }
            .background(BrutalistTheme.Colors.background)
            .navigationTitle("NEW TANK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") {
                        dismiss()
                    }
                    .font(BrutalistTheme.Typography.button)
                    .foregroundColor(BrutalistTheme.Colors.text)
                }
            }
        }
    }

    private func tankTypeButton(_ type: TankType) -> some View {
        Button(action: { selectedType = type }) {
            VStack(spacing: BrutalistTheme.Spacing.xs) {
                Text(type.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text)

                Text(type.description)
                    .font(.system(size: 9))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(BrutalistTheme.Spacing.sm)
            .background(selectedType == type ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
            .brutalistBorder(
                width: selectedType == type ? BrutalistTheme.Borders.standard : 2,
                color: selectedType == type ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.3)
            )
        }
        .buttonStyle(.plain)
    }

    private func createTank() {
        guard let volume = Double(volumeText), volume > 0 else { return }

        let tank = Tank(
            name: name,
            volumeGallons: volume,
            tankType: selectedType,
            notes: notes.isEmpty ? nil : notes
        )

        Task {
            await appState.createTank(tank)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("Tank List") {
    TankListView()
        .environmentObject(AppState())
}

#Preview("Add Tank Sheet") {
    AddTankSheet()
        .environmentObject(AppState())
}
