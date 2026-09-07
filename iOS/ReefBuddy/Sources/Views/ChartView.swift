import Charts
import SwiftUI

// MARK: - Chart View

/// Full-screen chart view with New Brutalist style line charts (Swift Charts).
/// Jagged lines, no fills, sharp corners, hard shadows.
struct ChartView: View {

    // MARK: - Properties

    let tank: Tank
    let measurements: [Measurement]
    let parameter: ParameterFilter
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPoint: ChartDataPoint?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chart Area
                chartContainer

                // Stats Summary
                statsSummary

                // Legend
                legendView
            }
            .background(BrutalistTheme.Colors.background)
            .navigationTitle(chartTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CLOSE") {
                        dismiss()
                    }
                    .font(BrutalistTheme.Typography.button)
                    .foregroundStyle(BrutalistTheme.Colors.text)
                }
            }
        }
    }

    // MARK: - Chart Container

    private var chartContainer: some View {
        VStack(spacing: 0) {
            // Selected Point Info
            selectedPointInfo
                .frame(height: 60)

            chart
                .padding(BrutalistTheme.Spacing.lg)
                .background(BrutalistTheme.Colors.background)
        }
        .brutalistCard()
        .padding(BrutalistTheme.Spacing.lg)
    }

    // MARK: - Chart (Swift Charts, brutalist styling: straight segments, square markers, hard grid)

    private var chart: some View {
        let data = Array(chartData.enumerated())
        let range = parameterRange.range
        let (minVal, maxVal) = chartValueRange

        return Chart {
            // Optimal range highlight
            RectangleMark(
                yStart: .value("Optimal low", range.lowerBound),
                yEnd: .value("Optimal high", range.upperBound)
            )
            .foregroundStyle(BrutalistTheme.Colors.action.opacity(0.1))

            ForEach(data, id: \.offset) { _, point in
                // Main line - jagged, no smoothing
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(parameter.displayName, point.value)
                )
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: BrutalistTheme.Borders.standard, lineCap: .square, lineJoin: .miter))
                .foregroundStyle(BrutalistTheme.Colors.text)

                // Square data point
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(parameter.displayName, point.value)
                )
                .symbol {
                    let isSelected = selectedPoint == point
                    Rectangle()
                        .fill(isSelected ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
                        .frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10)
                        .overlay(
                            Rectangle()
                                .strokeBorder(statusColor(for: point.value), lineWidth: isSelected ? 3 : 2)
                        )
                }
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.4))
            }
        }
        .chartYScale(domain: minVal...maxVal)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(max(chartData.count, 2), 7))) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.1))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.1))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(formatValue(number))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geometry[plotFrame].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    selectedPoint = nearestPoint(to: date)
                                }
                            }
                    )
            }
        }
    }

    /// The data point whose date is closest to `date` (touch selection).
    private func nearestPoint(to date: Date) -> ChartDataPoint? {
        chartData.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private var selectedPointInfo: some View {
        Group {
            if let point = selectedPoint {
                VStack(spacing: BrutalistTheme.Spacing.xs) {
                    Text(formatValue(point.value))
                        .font(BrutalistTheme.Typography.headerLarge)
                        .foregroundStyle(statusColor(for: point.value))

                    Text(formatDate(point.date))
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
                }
            } else {
                VStack(spacing: BrutalistTheme.Spacing.xs) {
                    Text("TAP CHART FOR DETAILS")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.5))

                    Text(parameter.displayName)
                        .font(BrutalistTheme.Typography.headerSmall)
                        .foregroundStyle(BrutalistTheme.Colors.text)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, BrutalistTheme.Spacing.md)
    }

    // MARK: - Stats Summary

    private var statsSummary: some View {
        HStack(spacing: 0) {
            statCell(label: "MIN", value: formatValue(statistics.min))
            statCell(label: "AVG", value: formatValue(statistics.avg))
            statCell(label: "MAX", value: formatValue(statistics.max))
            statCell(label: "TREND", value: statistics.trend)
        }
        .background(BrutalistTheme.Colors.background)
        .brutalistBorder()
        .padding(.horizontal, BrutalistTheme.Spacing.lg)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: BrutalistTheme.Spacing.xs) {
            Text(value)
                .font(BrutalistTheme.Typography.headerSmall)
                .foregroundStyle(BrutalistTheme.Colors.text)

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BrutalistTheme.Spacing.md)
        .overlay(
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(width: 1),
            alignment: .trailing
        )
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: BrutalistTheme.Spacing.lg) {
            legendItem(color: BrutalistTheme.Colors.action.opacity(0.3), label: "OPTIMAL RANGE")
            legendItem(color: BrutalistTheme.Colors.text, label: "YOUR DATA")
        }
        .padding(BrutalistTheme.Spacing.lg)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: BrutalistTheme.Spacing.sm) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 16)
                .brutalistBorder(width: 2)

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(BrutalistTheme.Colors.text.opacity(0.6))
        }
    }

    // MARK: - Computed Properties

    private var chartTitle: String {
        "\(parameter.displayName) TREND"
    }

    private var chartData: [ChartDataPoint] {
        measurements.reversed().compactMap { measurement -> ChartDataPoint? in
            guard let value = getParameterValue(from: measurement) else { return nil }
            return ChartDataPoint(date: measurement.measuredAt, value: value)
        }
    }

    private var chartValueRange: (min: Double, max: Double) {
        let values = chartData.map { $0.value }
        let range = parameterRange.range

        let dataMin = values.min() ?? range.lowerBound
        let dataMax = values.max() ?? range.upperBound

        // Include optimal range in visible area
        let min = Swift.min(dataMin, range.lowerBound) - (range.upperBound - range.lowerBound) * 0.1
        let max = Swift.max(dataMax, range.upperBound) + (range.upperBound - range.lowerBound) * 0.1

        return (min, max)
    }

    private var parameterRange: ParameterRange {
        switch parameter {
        case .all, .pH:
            return .pH
        case .alkalinity:
            return .alkalinity
        case .calcium:
            return .calcium
        case .magnesium:
            return .magnesium
        case .nitrate:
            return .nitrate
        case .phosphate:
            return .phosphate
        case .temperature:
            return .temperature
        case .salinity:
            return .salinity
        }
    }

    private var statistics: (min: Double?, avg: Double?, max: Double?, trend: String) {
        let values = chartData.map { $0.value }

        guard !values.isEmpty else {
            return (nil, nil, nil, "--")
        }

        let min = values.min()
        let max = values.max()
        let avg = values.reduce(0, +) / Double(values.count)

        // Calculate trend
        var trend = "--"
        if values.count >= 2 {
            let recent = Array(values.suffix(values.count / 2))
            let older = Array(values.prefix(values.count / 2))

            let recentAvg = recent.reduce(0, +) / Double(recent.count)
            let olderAvg = older.reduce(0, +) / Double(older.count)

            let change = ((recentAvg - olderAvg) / olderAvg) * 100

            if change > 5 {
                trend = "UP"
            } else if change < -5 {
                trend = "DOWN"
            } else {
                trend = "STABLE"
            }
        }

        return (min, avg, max, trend)
    }

    // MARK: - Helper Methods

    private func getParameterValue(from measurement: Measurement) -> Double? {
        switch parameter {
        case .all, .pH:
            return measurement.pH
        case .alkalinity:
            return measurement.alkalinity
        case .calcium:
            return measurement.calcium
        case .magnesium:
            return measurement.magnesium
        case .nitrate:
            return measurement.nitrate
        case .phosphate:
            return measurement.phosphate
        case .temperature:
            return measurement.temperature
        case .salinity:
            return measurement.salinity
        }
    }

    private func formatValue(_ value: Double?) -> String {
        guard let value = value else { return "--" }

        switch parameter {
        case .all, .pH:
            return String(format: "%.2f", value)
        case .alkalinity, .nitrate, .temperature:
            return String(format: "%.1f", value)
        case .calcium, .magnesium:
            return String(format: "%.0f", value)
        case .phosphate:
            return String(format: "%.2f", value)
        case .salinity:
            return String(format: "%.3f", value)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }

    private func statusColor(for value: Double) -> Color {
        let status = parameterRange.status(for: value)
        switch status {
        case .optimal:
            return BrutalistTheme.Colors.action
        case .low, .high:
            return BrutalistTheme.Colors.warning
        case .unknown:
            return BrutalistTheme.Colors.text
        }
    }
}

// MARK: - Chart Data Point

struct ChartDataPoint: Equatable {
    let date: Date
    let value: Double
}

// MARK: - Preview

#Preview {
    ChartView(
        tank: Tank.sample,
        measurements: Measurement.samples,
        parameter: .pH
    )
}
