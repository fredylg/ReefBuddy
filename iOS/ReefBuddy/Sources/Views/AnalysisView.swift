import SwiftUI

// MARK: - Analysis View

/// Standalone view for displaying AI analysis results.
/// Shows parameter overview, warnings, recommendations, and dosing advice.
struct AnalysisView: View {

    // MARK: - Properties

    let tank: Tank
    let measurement: Measurement
    let analysis: AnalysisResponse

    // MARK: - Environment

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var showingShareSheet = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: BrutalistTheme.Spacing.xl) {
                // Header Card
                headerCard

                // Parameter Status Grid
                parameterStatusGrid

                // Warnings Section
                if let warnings = analysis.warnings, !warnings.isEmpty {
                    warningsSection(warnings)
                }

                // Summary Section
                summarySection

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
            }
            .padding(BrutalistTheme.Spacing.lg)
        }
        .background(BrutalistTheme.Colors.background)
        .navigationTitle("ANALYSIS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [generateShareText()])
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                    Text(tank.name.uppercased())
                        .font(BrutalistTheme.Typography.headerMedium)
                        .foregroundColor(BrutalistTheme.Colors.text)

                    Text(tank.tankType.displayName)
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                }

                Spacer()

                // Overall Status Badge
                overallStatusBadge
            }

            // Date
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .bold))

                Text(formattedDate)
                    .font(BrutalistTheme.Typography.caption)
            }
            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.action.opacity(0.1))
        .brutalistCard()
    }

    private var overallStatusBadge: some View {
        let hasWarnings = (analysis.warnings?.isEmpty == false)
        let status = hasWarnings ? "ATTENTION NEEDED" : "LOOKING GOOD"
        let color = hasWarnings ? BrutalistTheme.Colors.warning : BrutalistTheme.Colors.action

        return Text(status)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(BrutalistTheme.Colors.text)
            .padding(.horizontal, BrutalistTheme.Spacing.sm)
            .padding(.vertical, BrutalistTheme.Spacing.xs)
            .background(color)
            .brutalistBorder(width: 2)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: measurement.measuredAt).uppercased()
    }

    // MARK: - Parameter Status Grid

    private var parameterStatusGrid: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            Text("PARAMETERS")
                .font(BrutalistTheme.Typography.headerSmall)
                .foregroundColor(BrutalistTheme.Colors.text)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BrutalistTheme.Spacing.md) {
                parameterCell("TEMP", value: measurement.temperature, unit: "°F", range: ParameterRange.temperature)
                parameterCell("SALINITY", value: measurement.salinity, unit: "SG", range: ParameterRange.salinity)
                parameterCell("pH", value: measurement.pH, unit: "", range: ParameterRange.pH)
                parameterCell("ALK", value: measurement.alkalinity, unit: "dKH", range: ParameterRange.alkalinity)
                parameterCell("CALCIUM", value: measurement.calcium, unit: "ppm", range: ParameterRange.calcium)
                parameterCell("MAG", value: measurement.magnesium, unit: "ppm", range: ParameterRange.magnesium)
                parameterCell("NO3", value: measurement.nitrate, unit: "ppm", range: ParameterRange.nitrate)
                parameterCell("PO4", value: measurement.phosphate, unit: "ppm", range: ParameterRange.phosphate)
            }
        }
    }

    private func parameterCell(_ label: String, value: Double?, unit: String, range: ParameterRange) -> some View {
        let status = range.status(for: value)
        let statusColor: Color = {
            switch status {
            case .optimal: return BrutalistTheme.Colors.action
            case .low, .high: return BrutalistTheme.Colors.warning
            case .unknown: return BrutalistTheme.Colors.text.opacity(0.3)
            }
        }()

        return VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            Text(label)
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let val = value {
                    Text(String(format: unit == "SG" ? "%.3f" : "%.1f", val))
                        .font(BrutalistTheme.Typography.headerMedium)
                        .foregroundColor(BrutalistTheme.Colors.text)

                    Text(unit)
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                } else {
                    Text("---")
                        .font(BrutalistTheme.Typography.headerMedium)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))
                }
            }

            Text(status.displayText)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(status == .unknown ? BrutalistTheme.Colors.text.opacity(0.5) : BrutalistTheme.Colors.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(status == .unknown ? 0.1 : 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.background)
        .brutalistBorder(width: 2, color: statusColor)
    }

    // MARK: - Warnings Section

    private func warningsSection(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.warning)

                Text("WARNINGS")
                    .font(BrutalistTheme.Typography.headerSmall)
                    .foregroundColor(BrutalistTheme.Colors.warning)
            }

            VStack(spacing: BrutalistTheme.Spacing.sm) {
                ForEach(warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: BrutalistTheme.Spacing.sm) {
                        Circle()
                            .fill(BrutalistTheme.Colors.warning)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        Text(warning)
                            .font(BrutalistTheme.Typography.body)
                            .foregroundColor(BrutalistTheme.Colors.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(BrutalistTheme.Spacing.md)
            .background(BrutalistTheme.Colors.warning.opacity(0.1))
            .brutalistBorder(width: BrutalistTheme.Borders.standard, color: BrutalistTheme.Colors.warning)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            Text("SUMMARY")
                .font(BrutalistTheme.Typography.headerSmall)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text(analysis.summary)
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(BrutalistTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrutalistTheme.Colors.background)
                .brutalistCard()
        }
    }

    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.action)

                Text("RECOMMENDATIONS")
                    .font(BrutalistTheme.Typography.headerSmall)
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            VStack(spacing: BrutalistTheme.Spacing.sm) {
                ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: BrutalistTheme.Spacing.md) {
                        Text("\(index + 1)")
                            .font(BrutalistTheme.Typography.bodyBold)
                            .foregroundColor(BrutalistTheme.Colors.text)
                            .frame(width: 24, height: 24)
                            .background(BrutalistTheme.Colors.action)

                        Text(recommendation)
                            .font(BrutalistTheme.Typography.body)
                            .foregroundColor(BrutalistTheme.Colors.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BrutalistTheme.Spacing.md)
                    .background(BrutalistTheme.Colors.action.opacity(0.1))
                    .brutalistBorder(width: 2, color: BrutalistTheme.Colors.action)
                }
            }
        }
    }

    // MARK: - Dosing Section

    private func dosingSection(_ dosing: [DosingRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            HStack {
                Image(systemName: "eyedropper")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text)

                Text("DOSING ADVICE")
                    .font(BrutalistTheme.Typography.headerSmall)
                    .foregroundColor(BrutalistTheme.Colors.text)
            }

            VStack(spacing: BrutalistTheme.Spacing.md) {
                ForEach(dosing) { advice in
                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
                        Text(advice.product.uppercased())
                            .font(BrutalistTheme.Typography.bodyBold)
                            .foregroundColor(BrutalistTheme.Colors.text)

                        HStack(spacing: BrutalistTheme.Spacing.lg) {
                            VStack(alignment: .leading) {
                                Text("AMOUNT")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                                Text(advice.amount)
                                    .font(BrutalistTheme.Typography.headerSmall)
                                    .foregroundColor(BrutalistTheme.Colors.action)
                            }

                            VStack(alignment: .leading) {
                                Text("FREQUENCY")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                                Text(advice.frequency)
                                    .font(BrutalistTheme.Typography.bodyBold)
                                    .foregroundColor(BrutalistTheme.Colors.text)
                            }
                        }

                        Text(advice.reason)
                            .font(BrutalistTheme.Typography.caption)
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.7))
                    }
                    .padding(BrutalistTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrutalistTheme.Colors.background)
                    .brutalistCard()
                }
            }
        }
    }

    // MARK: - Disclaimer Card

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: BrutalistTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("AI DISCLAIMER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text)

                Text("This analysis is generated by AI and is for reference only. Always verify readings with multiple tests. Consult a marine aquarium professional for critical issues.")
                    .font(.system(size: 11))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.7))
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.warning.opacity(0.1))
        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.warning.opacity(0.5))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            BrutalistButton.primary("LOG NEW MEASUREMENT", isFullWidth: true) {
                dismiss()
            }

            BrutalistButton.secondary("BACK TO TANK", isFullWidth: true) {
                dismiss()
            }
        }
    }

    // MARK: - Share Text

    private func generateShareText() -> String {
        var text = """
        REEFBUDDY ANALYSIS
        \(tank.name) - \(formattedDate)

        SUMMARY:
        \(analysis.summary)

        """

        if let warnings = analysis.warnings, !warnings.isEmpty {
            text += "\nWARNINGS:\n"
            warnings.forEach { text += "- \($0)\n" }
        }

        if !analysis.recommendations.isEmpty {
            text += "\nRECOMMENDATIONS:\n"
            analysis.recommendations.forEach { text += "- \($0)\n" }
        }

        text += "\n---\nGenerated by ReefBuddy"
        return text
    }
}


// MARK: - Preview

#Preview("Analysis View") {
    NavigationStack {
        AnalysisView(
            tank: Tank.sample,
            measurement: Measurement.sample,
            analysis: AnalysisResponse(
                summary: "Your tank parameters are mostly within optimal ranges. Alkalinity is slightly low at 7.2 dKH which may affect coral growth over time. Calcium and magnesium levels are good, maintaining proper ionic balance.",
                recommendations: [
                    "Increase alkalinity dosing by 10% to reach target of 8-9 dKH",
                    "Monitor calcium consumption over the next week",
                    "Consider a 10% water change this weekend",
                    "Test alkalinity again in 3 days to verify improvement"
                ],
                warnings: [
                    "Alkalinity is below recommended range (7.2 dKH, target: 8-11 dKH)"
                ],
                dosingAdvice: [
                    DosingRecommendation(
                        product: "Alkalinity Buffer",
                        amount: "15ml",
                        frequency: "Daily",
                        reason: "To raise dKH from 7.2 to target range of 8.5"
                    ),
                    DosingRecommendation(
                        product: "Calcium Chloride",
                        amount: "10ml",
                        frequency: "Every other day",
                        reason: "Maintain calcium balance with increased alkalinity"
                    )
                ]
            )
        )
        .environmentObject(AppState())
    }
}
