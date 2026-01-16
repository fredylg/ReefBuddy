import SwiftUI

// MARK: - Measurement Entry View

/// Form view for entering water parameters with New Brutalist styling.
/// Bold labels, high-contrast inputs, clear parameter groupings.
struct MeasurementEntryView: View {

    // MARK: - Properties

    let tank: Tank

    // MARK: - State

    @EnvironmentObject private var appState: AppState
    @State private var measurement: MeasurementDraft = MeasurementDraft()
    @State private var showingAnalysis = false
    @State private var analysisResult: AnalysisResponse?
    @State private var showingSaveConfirmation = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: BrutalistTheme.Spacing.xl) {
                // Tank Header
                tankHeader

                // Parameter Sections
                basicParametersSection
                alkalinitySection
                nutrientSection

                // Notes
                notesSection

                // Action Buttons
                actionButtons
            }
            .padding(BrutalistTheme.Spacing.lg)
        }
        .background(BrutalistTheme.Colors.background)
        .sheet(isPresented: $showingAnalysis) {
            if let analysis = analysisResult {
                AnalysisResultSheet(analysis: analysis)
            }
        }
        .alert("MEASUREMENT SAVED", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your water parameters have been recorded.")
        }
    }

    // MARK: - Tank Header

    private var tankHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                Text(tank.name.uppercased())
                    .font(BrutalistTheme.Typography.headerSmall)
                    .foregroundColor(BrutalistTheme.Colors.text)

                Text(tank.tankType.displayName)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
            }

            Spacer()

            Text(formattedDate)
                .font(BrutalistTheme.Typography.caption)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.action.opacity(0.1))
        .brutalistBorder()
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date()).uppercased()
    }

    // MARK: - Basic Parameters Section

    private var basicParametersSection: some View {
        parameterSection(title: "BASIC PARAMETERS") {
            VStack(spacing: BrutalistTheme.Spacing.md) {
                HStack(spacing: BrutalistTheme.Spacing.md) {
                    parameterField(
                        label: "TEMPERATURE",
                        value: $measurement.temperature,
                        unit: "°F",
                        range: ParameterRange.temperature.range,
                        placeholder: "78.0"
                    )

                    parameterField(
                        label: "SALINITY",
                        value: $measurement.salinity,
                        unit: "SG",
                        range: ParameterRange.salinity.range,
                        placeholder: "1.025"
                    )
                }

                parameterField(
                    label: "pH",
                    value: $measurement.pH,
                    unit: "",
                    range: ParameterRange.pH.range,
                    placeholder: "8.2"
                )
            }
        }
    }

    // MARK: - Alkalinity Section

    private var alkalinitySection: some View {
        parameterSection(title: "MAJOR ELEMENTS") {
            VStack(spacing: BrutalistTheme.Spacing.md) {
                parameterField(
                    label: "ALKALINITY",
                    value: $measurement.alkalinity,
                    unit: "dKH",
                    range: ParameterRange.alkalinity.range,
                    placeholder: "8.5"
                )

                HStack(spacing: BrutalistTheme.Spacing.md) {
                    parameterField(
                        label: "CALCIUM",
                        value: $measurement.calcium,
                        unit: "ppm",
                        range: ParameterRange.calcium.range,
                        placeholder: "420"
                    )

                    parameterField(
                        label: "MAGNESIUM",
                        value: $measurement.magnesium,
                        unit: "ppm",
                        range: ParameterRange.magnesium.range,
                        placeholder: "1350"
                    )
                }
            }
        }
    }

    // MARK: - Nutrient Section

    private var nutrientSection: some View {
        parameterSection(title: "NUTRIENTS") {
            VStack(spacing: BrutalistTheme.Spacing.md) {
                HStack(spacing: BrutalistTheme.Spacing.md) {
                    parameterField(
                        label: "NITRATE (NO3)",
                        value: $measurement.nitrate,
                        unit: "ppm",
                        range: ParameterRange.nitrate.range,
                        placeholder: "5.0"
                    )

                    parameterField(
                        label: "PHOSPHATE (PO4)",
                        value: $measurement.phosphate,
                        unit: "ppm",
                        range: ParameterRange.phosphate.range,
                        placeholder: "0.03"
                    )
                }

                HStack(spacing: BrutalistTheme.Spacing.md) {
                    parameterField(
                        label: "AMMONIA",
                        value: $measurement.ammonia,
                        unit: "ppm",
                        range: ParameterRange.ammonia.range,
                        placeholder: "0.0"
                    )

                    parameterField(
                        label: "NITRITE (NO2)",
                        value: $measurement.nitrite,
                        unit: "ppm",
                        range: ParameterRange.nitrite.range,
                        placeholder: "0.0"
                    )
                }
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        parameterSection(title: "OBSERVATIONS") {
            BrutalistTextArea(
                "Any observations about your tank today...",
                text: $measurement.notes,
                minHeight: 80
            )
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            // Analyze Button (Primary)
            BrutalistButton.primary("ANALYZE PARAMETERS", isFullWidth: true, isEnabled: hasAnyValue) {
                analyzeParameters()
            }

            // Save Button (Secondary)
            BrutalistButton.secondary("SAVE WITHOUT ANALYSIS", isFullWidth: true, isEnabled: hasAnyValue) {
                saveParameters()
            }

            // Disclaimer
            disclaimerView
        }
    }

    private var disclaimerView: some View {
        HStack(spacing: BrutalistTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(BrutalistTheme.Colors.warning)

            Text("AI recommendations are for reference only. Always test twice and consult a professional for serious issues.")
                .font(.system(size: 10))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.warning.opacity(0.1))
        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.warning.opacity(0.5))
    }

    // MARK: - Helper Views

    private func parameterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            Text(title)
                .font(BrutalistTheme.Typography.headerSmall)
                .foregroundColor(BrutalistTheme.Colors.text)

            content()
        }
    }

    private func parameterField(
        label: String,
        value: Binding<String>,
        unit: String,
        range: ClosedRange<Double>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            Text(label)
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)

            HStack(spacing: BrutalistTheme.Spacing.sm) {
                TextField(placeholder, text: value)
                    .font(BrutalistTheme.Typography.body)
                    .keyboardType(.decimalPad)
                    .foregroundColor(BrutalistTheme.Colors.text)

                if !unit.isEmpty {
                    Text(unit)
                        .font(BrutalistTheme.Typography.bodyBold)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                }
            }
            .padding(BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.background)
            .brutalistCard(
                borderColor: borderColor(for: value.wrappedValue, range: range)
            )

            // Range indicator
            Text("Target: \(formatRange(range))")
                .font(.system(size: 10))
                .foregroundColor(statusColor(for: value.wrappedValue, range: range))
        }
    }

    private func borderColor(for value: String, range: ClosedRange<Double>) -> Color {
        guard let numValue = Double(value) else { return BrutalistTheme.Colors.text }
        if range.contains(numValue) {
            return BrutalistTheme.Colors.action
        } else {
            return BrutalistTheme.Colors.warning
        }
    }

    private func statusColor(for value: String, range: ClosedRange<Double>) -> Color {
        guard let numValue = Double(value) else { return BrutalistTheme.Colors.text.opacity(0.5) }
        if range.contains(numValue) {
            return BrutalistTheme.Colors.action
        } else {
            return BrutalistTheme.Colors.warning
        }
    }

    private func formatRange(_ range: ClosedRange<Double>) -> String {
        if range.lowerBound == range.upperBound {
            return String(format: "%.1f", range.lowerBound)
        }
        return String(format: "%.1f - %.1f", range.lowerBound, range.upperBound)
    }

    // MARK: - Computed Properties

    private var hasAnyValue: Bool {
        !measurement.temperature.isEmpty ||
        !measurement.salinity.isEmpty ||
        !measurement.pH.isEmpty ||
        !measurement.alkalinity.isEmpty ||
        !measurement.calcium.isEmpty ||
        !measurement.magnesium.isEmpty ||
        !measurement.nitrate.isEmpty ||
        !measurement.phosphate.isEmpty
    }

    // MARK: - Actions

    private func analyzeParameters() {
        let measurementModel = measurement.toMeasurement(tankId: tank.id)

        Task {
            if let analysis = await appState.requestAnalysis(for: measurementModel) {
                analysisResult = analysis
                showingAnalysis = true

                // Also save the measurement
                await appState.submitMeasurement(measurementModel)
            }
        }
    }

    private func saveParameters() {
        let measurementModel = measurement.toMeasurement(tankId: tank.id)

        Task {
            await appState.submitMeasurement(measurementModel)
            showingSaveConfirmation = true
            measurement = MeasurementDraft() // Reset form
        }
    }
}

// MARK: - Measurement Draft

/// A draft measurement with string values for form editing
struct MeasurementDraft {
    var temperature: String = ""
    var salinity: String = ""
    var pH: String = ""
    var alkalinity: String = ""
    var calcium: String = ""
    var magnesium: String = ""
    var nitrate: String = ""
    var phosphate: String = ""
    var ammonia: String = ""
    var nitrite: String = ""
    var notes: String = ""

    func toMeasurement(tankId: UUID) -> Measurement {
        Measurement(
            tankId: tankId,
            temperature: Double(temperature),
            salinity: Double(salinity),
            pH: Double(pH),
            alkalinity: Double(alkalinity),
            calcium: Double(calcium),
            magnesium: Double(magnesium),
            nitrate: Double(nitrate),
            phosphate: Double(phosphate),
            ammonia: Double(ammonia),
            nitrite: Double(nitrite),
            notes: notes.isEmpty ? nil : notes
        )
    }
}

// MARK: - Analysis Result Sheet

/// Modal sheet displaying AI analysis results
struct AnalysisResultSheet: View {
    let analysis: AnalysisResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xl) {
                    // Summary
                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                        sectionHeader("SUMMARY")

                        Text(analysis.summary)
                            .font(BrutalistTheme.Typography.body)
                            .foregroundColor(BrutalistTheme.Colors.text)
                    }

                    // Warnings
                    if let warnings = analysis.warnings, !warnings.isEmpty {
                        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                            sectionHeader("WARNINGS", color: BrutalistTheme.Colors.warning)

                            ForEach(warnings, id: \.self) { warning in
                                warningItem(warning)
                            }
                        }
                    }

                    // Recommendations
                    if !analysis.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                            sectionHeader("RECOMMENDATIONS")

                            ForEach(analysis.recommendations, id: \.self) { recommendation in
                                recommendationItem(recommendation)
                            }
                        }
                    }

                    // Dosing Advice
                    if let dosing = analysis.dosingAdvice, !dosing.isEmpty {
                        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                            sectionHeader("DOSING ADVICE")

                            ForEach(dosing) { advice in
                                dosingItem(advice)
                            }
                        }
                    }

                    // Disclaimer
                    disclaimerView
                }
                .padding(BrutalistTheme.Spacing.lg)
            }
            .background(BrutalistTheme.Colors.background)
            .navigationTitle("ANALYSIS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") {
                        dismiss()
                    }
                    .font(BrutalistTheme.Typography.button)
                    .foregroundColor(BrutalistTheme.Colors.text)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, color: Color = BrutalistTheme.Colors.text) -> some View {
        Text(title)
            .font(BrutalistTheme.Typography.headerSmall)
            .foregroundColor(color)
    }

    private func warningItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: BrutalistTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.warning)

            Text(text)
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text)
        }
        .padding(BrutalistTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrutalistTheme.Colors.warning.opacity(0.1))
        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.warning)
    }

    private func recommendationItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: BrutalistTheme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.action)

            Text(text)
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text)
        }
        .padding(BrutalistTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrutalistTheme.Colors.action.opacity(0.1))
        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.action)
    }

    private func dosingItem(_ advice: DosingRecommendation) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            Text(advice.product.uppercased())
                .font(BrutalistTheme.Typography.bodyBold)
                .foregroundColor(BrutalistTheme.Colors.text)

            HStack {
                Text(advice.amount)
                    .font(BrutalistTheme.Typography.headerMedium)
                    .foregroundColor(BrutalistTheme.Colors.action)

                Text(advice.frequency)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
            }

            Text(advice.reason)
                .font(BrutalistTheme.Typography.caption)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .padding(BrutalistTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard()
    }

    private var disclaimerView: some View {
        HStack(spacing: BrutalistTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(BrutalistTheme.Colors.warning)

            Text("This analysis is AI-generated and for reference only. Always verify with multiple tests and consult professionals for critical issues.")
                .font(.system(size: 10))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.warning.opacity(0.1))
        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.warning.opacity(0.5))
    }
}

// MARK: - Preview

#Preview("Measurement Entry") {
    MeasurementEntryView(tank: Tank.sample)
        .environmentObject(AppState())
}

#Preview("Analysis Result") {
    AnalysisResultSheet(analysis: AnalysisResponse(
        summary: "Your tank parameters are mostly within optimal ranges. Alkalinity is slightly low which may affect coral growth over time.",
        recommendations: [
            "Increase alkalinity dosing by 10%",
            "Monitor calcium consumption closely",
            "Consider a 10% water change this week"
        ],
        warnings: [
            "Alkalinity is below target range"
        ],
        dosingAdvice: [
            DosingRecommendation(
                product: "Alkalinity Buffer",
                amount: "15ml",
                frequency: "Daily",
                reason: "To raise dKH from 7.2 to 8.5"
            )
        ]
    ))
}
