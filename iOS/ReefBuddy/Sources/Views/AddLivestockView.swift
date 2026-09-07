import SwiftUI
import PhotosUI

// MARK: - Add Livestock View

/// Form view for adding new livestock to a tank.
/// New Brutalist design: sharp corners, bold borders, high contrast.
struct AddLivestockView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // MARK: - Properties

    let tank: Tank

    // MARK: - Form State

    @State private var name: String = ""
    @State private var scientificName: String = ""
    @State private var selectedCategory: LivestockCategory = .fish
    @State private var quantity: Int = 1
    @State private var purchaseDate: Date = Date()
    @State private var priceText: String = ""
    @State private var notes: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingDatePicker = false

    // MARK: - Validation

    @State private var nameError: String?
    @State private var isSaving = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrutalistTheme.Spacing.lg) {
                    // Photo Picker
                    photoPickerSection

                    // Species Name
                    BrutalistTextField(
                        "e.g., Green Slimer, Clownfish",
                        text: $name,
                        label: "Name *",
                        errorText: nameError
                    )
                    .onChange(of: name) { _, _ in
                        nameError = nil
                    }

                    // Scientific Name
                    BrutalistTextField(
                        "e.g., Acropora yongei (optional)",
                        text: $scientificName,
                        label: "Scientific Name"
                    )

                    // Category Picker
                    categoryPicker

                    // Quantity Stepper
                    BrutalistStepper(
                        "Quantity",
                        value: $quantity,
                        range: 1...100
                    )

                    // Purchase Date
                    datePickerSection

                    // Price (Optional)
                    BrutalistTextField(
                        "0.00",
                        text: $priceText,
                        label: "Purchase Price (Optional)",
                        keyboardType: .decimalPad
                    )

                    // Notes
                    BrutalistTextArea(
                        "Care notes, placement, etc...",
                        text: $notes,
                        label: "Notes (Optional)"
                    )

                    // Save Button
                    BrutalistButton.primary("ADD LIVESTOCK", isFullWidth: true, isEnabled: !isSaving) {
                        saveLivestock()
                    }

                    // Bottom spacing
                    Spacer()
                        .frame(height: BrutalistTheme.Spacing.xl)
                }
                .padding(BrutalistTheme.Spacing.lg)
            }
            .background(BrutalistTheme.Colors.background)
            .navigationTitle("ADD LIVESTOCK")
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

    // MARK: - Photo Picker Section

    private var photoPickerSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            Text("PHOTO (OPTIONAL)")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundStyle(BrutalistTheme.Colors.text)

            // The PhotosPicker label closure is nonisolated in the SDK, so it only receives a plain value
            // and the main-actor work (styling, state mutation) lives in the label view and the overlay.
            let currentImage = photoData.flatMap(UIImage.init(data:))
            ZStack(alignment: .topTrailing) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    PhotoPickerLabel(image: currentImage)
                }

                if currentImage != nil {
                    // Remove photo button
                    Button(action: {
                        photoData = nil
                        selectedPhoto = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(BrutalistTheme.Colors.warning)
                            .background(Circle().fill(BrutalistTheme.Colors.background))
                    }
                    .buttonStyle(.plain)
                    .padding(BrutalistTheme.Spacing.sm)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                loadPhoto(from: newValue)
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            Text("CATEGORY *")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundStyle(BrutalistTheme.Colors.text)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: BrutalistTheme.Spacing.sm) {
                ForEach(LivestockCategory.allCases) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = category
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.system(size: 20, weight: .bold))

                            Text(category.displayName.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(BrutalistTheme.Colors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BrutalistTheme.Spacing.sm)
                        .background(selectedCategory == category ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
                        .brutalistBorder(width: selectedCategory == category ? BrutalistTheme.Borders.standard : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Date Picker Section

    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            Text("PURCHASE DATE")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundStyle(BrutalistTheme.Colors.text)

            Button(action: {
                withAnimation {
                    showingDatePicker.toggle()
                }
            }) {
                HStack {
                    Text(formatDate(purchaseDate))
                        .font(BrutalistTheme.Typography.body)
                        .foregroundStyle(BrutalistTheme.Colors.text)

                    Spacer()

                    Image(systemName: showingDatePicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BrutalistTheme.Colors.text)
                }
                .padding(BrutalistTheme.Spacing.md)
                .background(BrutalistTheme.Colors.background)
                .brutalistBorder()
            }
            .buttonStyle(.plain)

            if showingDatePicker {
                DatePicker(
                    "Purchase Date",
                    selection: $purchaseDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(BrutalistTheme.Spacing.sm)
                .background(BrutalistTheme.Colors.background)
                .brutalistBorder()
                .tint(BrutalistTheme.Colors.action)
            }
        }
    }

    // MARK: - Helper Functions

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.photoData = data
                }
            }
        }
    }

    private func saveLivestock() {
        // Validate
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            nameError = "Name is required"
            return
        }

        isSaving = true

        // Parse price
        let price: Double? = {
            let cleaned = priceText.replacingOccurrences(of: "$", with: "")
            return Double(cleaned)
        }()

        // Create livestock
        let livestock = Livestock(
            tankId: tank.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            scientificName: scientificName.isEmpty ? nil : scientificName.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory,
            healthStatus: .healthy,
            quantity: quantity,
            purchaseDate: purchaseDate,
            purchasePrice: price,
            photoData: photoData,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        Task {
            await appState.addLivestock(livestock)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview("Add Livestock") {
    AddLivestockView(tank: Tank.sample)
        .environment(AppState())
}

#Preview("Add Livestock - Filled") {
    let view = AddLivestockView(tank: Tank.sample)
    return view
        .environment(AppState())
}

// MARK: - Photo Picker Label

/// Label content for the livestock photo picker: the chosen image, or the "tap to add" placeholder.
private struct PhotoPickerLabel: View {
    let image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()
                .brutalistBorder()
        } else {
            HStack {
                Spacer()
                VStack(spacing: BrutalistTheme.Spacing.sm) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.4))

                    Text("TAP TO ADD PHOTO")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.4))
                }
                Spacer()
            }
            .frame(height: 140)
            .background(BrutalistTheme.Colors.text.opacity(0.05))
            .brutalistBorder(width: BrutalistTheme.Borders.standard, color: BrutalistTheme.Colors.text.opacity(0.3))
        }
    }
}
