import SwiftUI

// MARK: - Chart View

/// Full-screen chart view with New Brutalist style line charts.
/// Jagged lines, no fills, sharp corners, hard shadows.
struct ChartView: View {

    // MARK: - Properties

    let tank: Tank
    let measurements: [Measurement]
    let parameter: ParameterFilter
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPoint: ChartDataPoint?
    @State private var showingSubscription = false

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
                    .foregroundColor(BrutalistTheme.Colors.text)
                }
            }
        }
        .sheet(isPresented: $showingSubscription) {
            PurchaseCreditsView()
        }
    }

    // MARK: - Chart Container

    private var chartContainer: some View {
        VStack(spacing: 0) {
            // Selected Point Info
            selectedPointInfo
                .frame(height: 60)

            // Chart
            GeometryReader { geometry in
                ZStack {
                    // Grid lines
                    gridLines(in: geometry.size)

                    // Chart line
                    brutalistChartLine(in: geometry.size)

                    // Data points
                    dataPoints(in: geometry.size)

                    // Touch overlay
                    touchOverlay(in: geometry.size)
                }
            }
            .padding(BrutalistTheme.Spacing.lg)
            .background(BrutalistTheme.Colors.background)
        }
        .brutalistCard()
        .padding(BrutalistTheme.Spacing.lg)
    }

    private var selectedPointInfo: some View {
        Group {
            if let point = selectedPoint {
                VStack(spacing: BrutalistTheme.Spacing.xs) {
                    Text(formatValue(point.value))
                        .font(BrutalistTheme.Typography.headerLarge)
                        .foregroundColor(statusColor(for: point.value))

                    Text(formatDate(point.date))
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                }
            } else {
                VStack(spacing: BrutalistTheme.Spacing.xs) {
                    Text("TAP CHART FOR DETAILS")
                        .font(BrutalistTheme.Typography.caption)
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))

                    Text(parameter.displayName)
                        .font(BrutalistTheme.Typography.headerSmall)
                        .foregroundColor(BrutalistTheme.Colors.text)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, BrutalistTheme.Spacing.md)
    }

    // MARK: - Grid Lines

    private func gridLines(in size: CGSize) -> some View {
        let horizontalLines = 5
        let verticalLines = min(chartData.count, 7)

        return ZStack {
            // Horizontal grid lines
            ForEach(0..<horizontalLines, id: \.self) { index in
                let y = size.height * CGFloat(index) / CGFloat(horizontalLines - 1)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(
                    BrutalistTheme.Colors.text.opacity(0.1),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }

            // Vertical grid lines
            if verticalLines > 1 {
                ForEach(0..<verticalLines, id: \.self) { index in
                    let x = size.width * CGFloat(index) / CGFloat(verticalLines - 1)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    .stroke(
                        BrutalistTheme.Colors.text.opacity(0.1),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                }
            }

            // Optimal range highlight
            optimalRangeOverlay(in: size)
        }
    }

    private func optimalRangeOverlay(in size: CGSize) -> some View {
        let range = parameterRange
        let (minVal, maxVal) = chartValueRange

        guard maxVal > minVal else { return AnyView(EmptyView()) }

        let normalizedLower = CGFloat((range.range.lowerBound - minVal) / (maxVal - minVal))
        let normalizedUpper = CGFloat((range.range.upperBound - minVal) / (maxVal - minVal))

        let yLower = size.height * (1 - normalizedLower)
        let yUpper = size.height * (1 - normalizedUpper)

        return AnyView(
            Rectangle()
                .fill(BrutalistTheme.Colors.action.opacity(0.1))
                .frame(height: abs(yLower - yUpper))
                .position(x: size.width / 2, y: (yLower + yUpper) / 2)
        )
    }

    // MARK: - Brutalist Chart Line

    private func brutalistChartLine(in size: CGSize) -> some View {
        let points = getChartPoints(in: size)

        return ZStack {
            // Main line - jagged, no smoothing
            if points.count > 1 {
                Path { path in
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        // Direct lines, no curves - true brutalist style
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    BrutalistTheme.Colors.text,
                    style: StrokeStyle(
                        lineWidth: BrutalistTheme.Borders.standard,
                        lineCap: .square,
                        lineJoin: .miter
                    )
                )
            }
        }
    }

    // MARK: - Data Points

    private func dataPoints(in size: CGSize) -> some View {
        let points = getChartPoints(in: size)
        let data = chartData

        return ZStack {
            ForEach(Array(zip(points.indices, points)), id: \.0) { index, point in
                let dataPoint = data[index]
                let isSelected = selectedPoint?.date == dataPoint.date

                // Square data point - brutalist style
                Rectangle()
                    .fill(isSelected ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
                    .frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10)
                    .overlay(
                        Rectangle()
                            .strokeBorder(
                                statusColor(for: dataPoint.value),
                                lineWidth: isSelected ? 3 : 2
                            )
                    )
                    .position(point)
            }
        }
    }

    // MARK: - Touch Overlay

    private func touchOverlay(in size: CGSize) -> some View {
        let points = getChartPoints(in: size)
        let data = chartData

        return Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = value.location

                        // Find closest point
                        var closestIndex = 0
                        var closestDistance = CGFloat.infinity

                        for (index, point) in points.enumerated() {
                            let distance = abs(point.x - location.x)
                            if distance < closestDistance {
                                closestDistance = distance
                                closestIndex = index
                            }
                        }

                        if closestIndex < data.count {
                            selectedPoint = data[closestIndex]
                        }
                    }
                    .onEnded { _ in
                        // Keep selection visible
                    }
            )
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
                .foregroundColor(BrutalistTheme.Colors.text)

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
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
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
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

    private func getChartPoints(in size: CGSize) -> [CGPoint] {
        let data = chartData
        guard data.count > 0 else { return [] }

        let (minVal, maxVal) = chartValueRange
        let valueRange = maxVal - minVal

        guard valueRange > 0 else { return [] }

        let padding: CGFloat = 8

        return data.enumerated().map { index, point in
            let x: CGFloat
            if data.count == 1 {
                x = size.width / 2
            } else {
                x = padding + CGFloat(index) / CGFloat(data.count - 1) * (size.width - padding * 2)
            }

            let normalizedY = (point.value - minVal) / valueRange
            let y = size.height - padding - CGFloat(normalizedY) * (size.height - padding * 2)

            return CGPoint(x: x, y: y)
        }
    }

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
