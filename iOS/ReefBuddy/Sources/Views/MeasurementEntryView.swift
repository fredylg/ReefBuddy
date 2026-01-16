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
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAnalyzing = false

    // MARK: - Body

    var body: some View {
        ZStack {
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

            // Loading Overlay
            if isAnalyzing {
                BrutalistLoadingView()
            }
        }
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
        .alert("ANALYSIS ERROR", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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

        isAnalyzing = true

        Task {
            if let analysis = await appState.requestAnalysis(for: measurementModel, tank: tank) {
                await MainActor.run {
                    isAnalyzing = false
                    analysisResult = analysis
                    showingAnalysis = true
                }

                // Also save the measurement
                await appState.submitMeasurement(measurementModel)
            } else if let error = appState.errorMessage {
                // Show error to user
                await MainActor.run {
                    isAnalyzing = false
                    errorMessage = error
                    showingError = true
                }
            } else {
                await MainActor.run {
                    isAnalyzing = false
                }
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

/// Modal sheet displaying AI analysis results with New Brutalist design
struct AnalysisResultSheet: View {
    let analysis: AnalysisResponse
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var showingSavedConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                BrutalistTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Header
                        heroHeader

                        VStack(spacing: BrutalistTheme.Spacing.xl) {
                            // AI Analysis Card
                            analysisCard

                            // Warnings Section
                            if let warnings = analysis.warnings, !warnings.isEmpty {
                                warningsSection(warnings)
                            }

                            // Recommendations Section
                            if !analysis.recommendations.isEmpty {
                                recommendationsSection
                            }

                            // Dosing Advice Section
                            if let dosing = analysis.dosingAdvice, !dosing.isEmpty {
                                dosingSection(dosing)
                            }

                            // Disclaimer
                            disclaimerCard

                            // Action Buttons
                            actionButtons

                            Spacer(minLength: BrutalistTheme.Spacing.xl)
                        }
                        .padding(.horizontal, BrutalistTheme.Spacing.lg)
                        .padding(.top, BrutalistTheme.Spacing.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .black))
                            Text("CLOSE")
                                .font(.system(size: 12, weight: .black))
                        }
                        .foregroundColor(BrutalistTheme.Colors.text)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(BrutalistTheme.Colors.text)
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [generateShareText()])
        }
        .alert("ANALYSIS SAVED", isPresented: $showingSavedConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your analysis has been saved to your measurement history.")
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 0) {
            // Status Banner
            HStack {
                VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                    Text("AI ANALYSIS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))

                    Text("COMPLETE")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(BrutalistTheme.Colors.text)
                }

                Spacer()

                // Status Badge
                statusBadge
            }
            .padding(BrutalistTheme.Spacing.lg)
            .background(BrutalistTheme.Colors.action)

            // Timestamp Bar
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .bold))

                Text(formattedDate.uppercased())
                    .font(.system(size: 10, weight: .bold))

                Spacer()

                Text("POWERED BY CLAUDE")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(BrutalistTheme.Colors.text)
            .padding(.horizontal, BrutalistTheme.Spacing.lg)
            .padding(.vertical, BrutalistTheme.Spacing.sm)
            .background(BrutalistTheme.Colors.text.opacity(0.1))
        }
    }

    private var statusBadge: some View {
        let hasWarnings = (analysis.warnings?.isEmpty == false)

        return VStack(spacing: 2) {
            Image(systemName: hasWarnings ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.system(size: 24, weight: .bold))

            Text(hasWarnings ? "REVIEW" : "GOOD")
                .font(.system(size: 10, weight: .black))
        }
        .foregroundColor(BrutalistTheme.Colors.text)
        .frame(width: 60, height: 60)
        .background(hasWarnings ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.background)
        .brutalistBorder(width: 3)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        return formatter.string(from: Date())
    }

    // MARK: - Analysis Card

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            // Section Header
            HStack {
                Rectangle()
                    .fill(BrutalistTheme.Colors.text)
                    .frame(width: 4, height: 20)

                Text("SUMMARY")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            // Analysis Text
            Text(analysis.summary)
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BrutalistTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard()
    }

    // MARK: - Warnings Section

    private func warningsSection(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            // Section Header
            HStack {
                Rectangle()
                    .fill(BrutalistTheme.Colors.warning)
                    .frame(width: 4, height: 20)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.warning)

                Text("WARNINGS")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(BrutalistTheme.Colors.warning)

                Spacer()

                Text("\(warnings.count)")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BrutalistTheme.Colors.warning)
            }

            // Warning Items
            VStack(spacing: BrutalistTheme.Spacing.sm) {
                ForEach(warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: BrutalistTheme.Spacing.md) {
                        Text("!")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(BrutalistTheme.Colors.text)
                            .frame(width: 24, height: 24)
                            .background(BrutalistTheme.Colors.warning)

                        Text(warning)
                            .font(BrutalistTheme.Typography.body)
                            .foregroundColor(BrutalistTheme.Colors.text)
                    }
                    .padding(BrutalistTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrutalistTheme.Colors.warning.opacity(0.15))
                    .brutalistBorder(width: 2, color: BrutalistTheme.Colors.warning)
                }
            }
        }
    }

    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            // Section Header
            HStack {
                Rectangle()
                    .fill(BrutalistTheme.Colors.action)
                    .frame(width: 4, height: 20)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text)

                Text("RECOMMENDATIONS")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            // Recommendation Items
            VStack(spacing: BrutalistTheme.Spacing.sm) {
                ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: BrutalistTheme.Spacing.md) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(BrutalistTheme.Colors.text)
                            .frame(width: 28, height: 28)
                            .background(BrutalistTheme.Colors.action)

                        Text(recommendation)
                            .font(BrutalistTheme.Typography.body)
                            .foregroundColor(BrutalistTheme.Colors.text)
                    }
                    .padding(BrutalistTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrutalistTheme.Colors.action.opacity(0.15))
                    .brutalistBorder(width: 2, color: BrutalistTheme.Colors.action)
                }
            }
        }
    }

    // MARK: - Dosing Section

    private func dosingSection(_ dosing: [DosingRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            // Section Header
            HStack {
                Rectangle()
                    .fill(BrutalistTheme.Colors.text)
                    .frame(width: 4, height: 20)

                Image(systemName: "eyedropper.halffull")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text)

                Text("DOSING ADVICE")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            // Dosing Items
            VStack(spacing: BrutalistTheme.Spacing.md) {
                ForEach(dosing) { advice in
                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                        // Product Name
                        Text(advice.product.uppercased())
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))

                        // Amount & Frequency
                        HStack(alignment: .firstTextBaseline, spacing: BrutalistTheme.Spacing.md) {
                            Text(advice.amount)
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(BrutalistTheme.Colors.action)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("FREQUENCY")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))

                                Text(advice.frequency.uppercased())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(BrutalistTheme.Colors.text)
                            }
                        }

                        // Reason
                        Text(advice.reason)
                            .font(BrutalistTheme.Typography.caption)
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.7))
                    }
                    .padding(BrutalistTheme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrutalistTheme.Colors.background)
                    .brutalistCard()
                }
            }
        }
    }

    // MARK: - Disclaimer Card

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: BrutalistTheme.Spacing.md) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.4))

            VStack(alignment: .leading, spacing: 4) {
                Text("AI DISCLAIMER")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))

                Text("This analysis is generated by AI and is for reference only. Always verify readings with multiple tests and consult a marine aquarium professional for critical issues.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                    .lineSpacing(2)
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrutalistTheme.Colors.text.opacity(0.05))
        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.text.opacity(0.2))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            // Save Analysis Button
            Button(action: saveAnalysis) {
                HStack(spacing: BrutalistTheme.Spacing.sm) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 16, weight: .bold))

                    Text("SAVE ANALYSIS")
                        .font(.system(size: 14, weight: .black))
                }
                .foregroundColor(BrutalistTheme.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BrutalistTheme.Spacing.md)
                .background(BrutalistTheme.Colors.action)
                .brutalistCard()
            }

            // Share Button
            Button(action: { showingShareSheet = true }) {
                HStack(spacing: BrutalistTheme.Spacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))

                    Text("SHARE RESULTS")
                        .font(.system(size: 14, weight: .black))
                }
                .foregroundColor(BrutalistTheme.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BrutalistTheme.Spacing.md)
                .background(BrutalistTheme.Colors.background)
                .brutalistBorder()
            }

            // Done Button
            Button(action: { dismiss() }) {
                Text("DONE")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BrutalistTheme.Spacing.md)
            }
        }
    }

    // MARK: - Actions

    private func saveAnalysis() {
        // For now, just show confirmation
        // In production, this would save to local storage or sync to backend
        showingSavedConfirmation = true
    }

    private func generateShareText() -> String {
        var text = """
        ═══════════════════════════════
        REEFBUDDY AI ANALYSIS
        \(formattedDate.uppercased())
        ═══════════════════════════════

        SUMMARY:
        \(analysis.summary)

        """

        if let warnings = analysis.warnings, !warnings.isEmpty {
            text += "\n⚠️ WARNINGS:\n"
            warnings.forEach { text += "• \($0)\n" }
        }

        if !analysis.recommendations.isEmpty {
            text += "\n💡 RECOMMENDATIONS:\n"
            analysis.recommendations.enumerated().forEach { index, rec in
                text += "\(index + 1). \(rec)\n"
            }
        }

        if let dosing = analysis.dosingAdvice, !dosing.isEmpty {
            text += "\n💧 DOSING ADVICE:\n"
            dosing.forEach { advice in
                text += "• \(advice.product): \(advice.amount) - \(advice.frequency)\n"
            }
        }

        text += "\n───────────────────────────────\nGenerated by ReefBuddy 🐠"
        return text
    }
}

// MARK: - Brutalist Loading View

/// Full-screen loading overlay with animated progress bar in brutalist style
struct BrutalistLoadingView: View {
    @State private var progress: CGFloat = 0
    @State private var isAnimating = false
    @State private var dotCount = 0

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Semi-transparent background
            BrutalistTheme.Colors.background
                .opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: BrutalistTheme.Spacing.xl) {
                // AI Icon
                ZStack {
                    Rectangle()
                        .fill(BrutalistTheme.Colors.text)
                        .frame(width: 80, height: 80)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(BrutalistTheme.Colors.background)
                }
                .brutalistShadow()

                // Loading Text
                VStack(spacing: BrutalistTheme.Spacing.sm) {
                    Text("ANALYZING")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(BrutalistTheme.Colors.text)

                    Text("PARAMETERS" + String(repeating: ".", count: dotCount))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.7))
                        .frame(width: 160, alignment: .leading)
                }

                // Progress Bar Container
                VStack(spacing: BrutalistTheme.Spacing.md) {
                    // Progress Bar
                    ZStack(alignment: .leading) {
                        // Background Track
                        Rectangle()
                            .fill(BrutalistTheme.Colors.text.opacity(0.2))
                            .frame(height: 12)

                        // Animated Progress
                        Rectangle()
                            .fill(BrutalistTheme.Colors.action)
                            .frame(width: progress * 240, height: 12)
                    }
                    .frame(width: 240, height: 12)
                    .brutalistBorder(width: 3, color: BrutalistTheme.Colors.text)

                    // Status Text
                    Text("AI PROCESSING")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                        .tracking(2)
                }

                // Decorative Elements
                HStack(spacing: BrutalistTheme.Spacing.sm) {
                    ForEach(0..<3) { index in
                        Rectangle()
                            .fill(index <= Int(progress * 3) ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.text.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(BrutalistTheme.Spacing.xxl)
        }
        .onAppear {
            startAnimation()
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }

    private func startAnimation() {
        // Indeterminate progress animation
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            progress = 1.0
        }
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
