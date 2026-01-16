import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export View

/// Export measurements to CSV with date range selection.
/// Premium-only feature with upgrade prompt for free users.
struct ExportView: View {

    // MARK: - Properties

    let tank: Tank
    let measurements: [Measurement]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var showingSubscription = false
    @State private var exportURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isPremium {
                    premiumContent
                } else {
                    freeContent
                }
            }
            .background(BrutalistTheme.Colors.background)
            .navigationTitle("EXPORT DATA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CLOSE") {
                        dismiss()
                    }
                    .font(BrutalistTheme.Typography.button)
                    .foregroundColor(BrutalistTheme.Colors.text)
                }
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("EXPORT ERROR", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Premium Content

    private var premiumContent: some View {
        ScrollView {
            VStack(spacing: BrutalistTheme.Spacing.xl) {
                // Header
                exportHeader

                // Date Range Selection
                dateRangeSection

                // Preview
                previewSection

                // Export Button
                exportButton
            }
            .padding(BrutalistTheme.Spacing.lg)
        }
    }

    // MARK: - Free Content (Premium Gate)

    private var freeContent: some View {
        VStack(spacing: BrutalistTheme.Spacing.xl) {
            Spacer()

            PremiumGateView(feature: "CSV Export") {
                showingSubscription = true
            }

            Spacer()
        }
        .padding(BrutalistTheme.Spacing.lg)
    }

    // MARK: - Export Header

    private var exportHeader: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            // Icon
            ZStack {
                Rectangle()
                    .fill(BrutalistTheme.Colors.action)
                    .frame(width: 60, height: 60)
                    .brutalistShadow(offset: 3)
                    .brutalistBorder(width: 2)

                Image(systemName: "doc.text")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            Text("EXPORT TO CSV")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text("Download your measurements for \(tank.name)")
                .font(BrutalistTheme.Typography.caption)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            Text("DATE RANGE")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)

            // Quick range buttons
            HStack(spacing: BrutalistTheme.Spacing.sm) {
                quickRangeButton("7D", days: 7)
                quickRangeButton("30D", days: 30)
                quickRangeButton("90D", days: 90)
                quickRangeButton("ALL", days: nil)
            }

            // Date pickers
            VStack(spacing: BrutalistTheme.Spacing.sm) {
                datePickerRow(label: "FROM", date: $startDate)
                datePickerRow(label: "TO", date: $endDate)
            }
        }
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard()
    }

    private func quickRangeButton(_ label: String, days: Int?) -> some View {
        Button(action: {
            if let days = days {
                startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            } else {
                startDate = Date.distantPast
            }
            endDate = Date()
        }) {
            Text(label)
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BrutalistTheme.Spacing.sm)
                .background(BrutalistTheme.Colors.background)
                .brutalistBorder(width: 2)
        }
        .buttonStyle(.plain)
    }

    private func datePickerRow(label: String, date: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .frame(width: 50, alignment: .leading)

            DatePicker(
                "",
                selection: date,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
        .padding(BrutalistTheme.Spacing.sm)
        .background(BrutalistTheme.Colors.text.opacity(0.05))
        .brutalistBorder(width: 1, color: BrutalistTheme.Colors.text.opacity(0.2))
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            HStack {
                Text("PREVIEW")
                    .font(BrutalistTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(BrutalistTheme.Colors.text)

                Spacer()

                Text("\(filteredMeasurements.count) RECORDS")
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.action)
            }

            // CSV Preview
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                Text(csvHeader)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(BrutalistTheme.Colors.action)
                    .lineLimit(1)

                // Data rows
                ForEach(previewRows.prefix(3), id: \.self) { row in
                    Text(row)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.7))
                        .lineLimit(1)
                }

                if filteredMeasurements.count > 3 {
                    Text("... \(filteredMeasurements.count - 3) more rows")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.text.opacity(0.05))
            .brutalistBorder(width: 1, color: BrutalistTheme.Colors.text.opacity(0.2))
        }
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard()
    }

    // MARK: - Export Button

    private var exportButton: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            Button(action: exportCSV) {
                HStack(spacing: BrutalistTheme.Spacing.sm) {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: BrutalistTheme.Colors.text))
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                    }

                    Text(isExporting ? "EXPORTING..." : "EXPORT CSV")
                        .font(BrutalistTheme.Typography.button)
                }
                .foregroundColor(BrutalistTheme.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(BrutalistTheme.Spacing.lg)
                .background(filteredMeasurements.isEmpty ? BrutalistTheme.Colors.disabled : BrutalistTheme.Colors.action)
                .brutalistCard()
            }
            .buttonStyle(.plain)
            .disabled(isExporting || filteredMeasurements.isEmpty)

            if filteredMeasurements.isEmpty {
                Text("No measurements in selected date range")
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.warning)
            }
        }
    }

    // MARK: - Computed Properties

    private var isPremium: Bool {
        // In real app, check user subscription status
        // For demo, returning true to show the export UI
        true
    }

    private var filteredMeasurements: [Measurement] {
        measurements.filter { measurement in
            measurement.measuredAt >= startDate && measurement.measuredAt <= endDate
        }.sorted { $0.measuredAt > $1.measuredAt }
    }

    private var csvHeader: String {
        "Date,Time,Temp,Sal,pH,Alk,Ca,Mg,NO3,PO4,NH3,NO2,Notes"
    }

    private var previewRows: [String] {
        filteredMeasurements.map { measurement in
            formatMeasurementAsCSV(measurement)
        }
    }

    // MARK: - Helper Methods

    private func formatMeasurementAsCSV(_ measurement: Measurement) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: measurement.measuredAt)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let time = timeFormatter.string(from: measurement.measuredAt)

        let temp = measurement.temperature.map { String(format: "%.1f", $0) } ?? ""
        let sal = measurement.salinity.map { String(format: "%.3f", $0) } ?? ""
        let ph = measurement.pH.map { String(format: "%.2f", $0) } ?? ""
        let alk = measurement.alkalinity.map { String(format: "%.1f", $0) } ?? ""
        let ca = measurement.calcium.map { String(format: "%.0f", $0) } ?? ""
        let mg = measurement.magnesium.map { String(format: "%.0f", $0) } ?? ""
        let no3 = measurement.nitrate.map { String(format: "%.1f", $0) } ?? ""
        let po4 = measurement.phosphate.map { String(format: "%.2f", $0) } ?? ""
        let nh3 = measurement.ammonia.map { String(format: "%.2f", $0) } ?? ""
        let no2 = measurement.nitrite.map { String(format: "%.2f", $0) } ?? ""
        let notes = measurement.notes?.replacingOccurrences(of: ",", with: ";") ?? ""

        return "\(date),\(time),\(temp),\(sal),\(ph),\(alk),\(ca),\(mg),\(no3),\(po4),\(nh3),\(no2),\(notes)"
    }

    private func exportCSV() {
        isExporting = true

        // Build CSV content
        var csvContent = csvHeader + "\n"
        for measurement in filteredMeasurements {
            csvContent += formatMeasurementAsCSV(measurement) + "\n"
        }

        // Create temporary file
        let fileName = "reefbuddy_\(tank.name.lowercased().replacingOccurrences(of: " ", with: "_"))_\(formattedDateRange).csv"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            exportURL = fileURL
            isExporting = false
            showingShareSheet = true
        } catch {
            isExporting = false
            errorMessage = "Failed to create export file: \(error.localizedDescription)"
            showingError = true
        }
    }

    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return "\(formatter.string(from: startDate))-\(formatter.string(from: endDate))"
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ExportView(tank: Tank.sample, measurements: Measurement.samples)
        .environmentObject(AppState())
}
