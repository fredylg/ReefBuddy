import SwiftUI

// MARK: - History View

/// Displays historical measurements with filtering and date range selection.
/// New Brutalist style: high contrast, sharp edges, bold typography.
struct HistoryView: View {

    // MARK: - Properties

    let tank: Tank
    @EnvironmentObject private var appState: AppState
    @State private var selectedRange: DateRange = .week
    @State private var selectedParameter: ParameterFilter = .all
    @State private var isRefreshing = false
    @State private var showingChart = false
    @State private var showingExport = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Filter Controls
            filterBar

            // Content
            ScrollView {
                VStack(spacing: BrutalistTheme.Spacing.lg) {
                    // Chart Preview Card
                    chartPreviewCard

                    // Measurements List
                    measurementsList
                }
                .padding(BrutalistTheme.Spacing.lg)
            }
            .refreshable {
                await refreshData()
            }
        }
        .background(BrutalistTheme.Colors.background)
        .task {
            // Fetch measurements from backend on view appear (syncs with local storage)
            await appState.fetchMeasurements(for: tank)
        }
        .sheet(isPresented: $showingChart) {
            ChartView(
                tank: tank,
                measurements: filteredMeasurements,
                parameter: selectedParameter
            )
        }
        .sheet(isPresented: $showingExport) {
            ExportView(tank: tank, measurements: filteredMeasurements)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 0) {
            // Date Range Selector
            HStack(spacing: 0) {
                ForEach(DateRange.allCases, id: \.self) { range in
                    dateRangeButton(range)
                }
            }
            .background(BrutalistTheme.Colors.background)
            .overlay(
                Rectangle()
                    .strokeBorder(BrutalistTheme.Colors.text, lineWidth: BrutalistTheme.Borders.standard)
            )
            .padding(.horizontal, BrutalistTheme.Spacing.lg)
            .padding(.top, BrutalistTheme.Spacing.md)

            // Parameter Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrutalistTheme.Spacing.sm) {
                    ForEach(ParameterFilter.allCases, id: \.self) { param in
                        parameterButton(param)
                    }
                }
                .padding(.horizontal, BrutalistTheme.Spacing.lg)
                .padding(.vertical, BrutalistTheme.Spacing.md)
            }

            // Divider
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: BrutalistTheme.Borders.standard)
        }
        .background(BrutalistTheme.Colors.background)
    }

    private func dateRangeButton(_ range: DateRange) -> some View {
        Button(action: { selectedRange = range }) {
            Text(range.displayName)
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BrutalistTheme.Spacing.sm)
                .background(selectedRange == range ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
        }
        .buttonStyle(.plain)
    }

    private func parameterButton(_ param: ParameterFilter) -> some View {
        Button(action: { selectedParameter = param }) {
            Text(param.displayName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(selectedParameter == param ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.5))
                .padding(.horizontal, BrutalistTheme.Spacing.sm)
                .padding(.vertical, BrutalistTheme.Spacing.xs)
                .background(selectedParameter == param ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
                .brutalistBorder(
                    width: 2,
                    color: selectedParameter == param ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.3)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart Preview Card

    private var chartPreviewCard: some View {
        Button(action: { showingChart = true }) {
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                        Text("TREND CHART")
                            .font(BrutalistTheme.Typography.headerSmall)
                            .foregroundColor(BrutalistTheme.Colors.text)

                        Text("\(selectedParameter.displayName) over \(selectedRange.displayName.lowercased())")
                            .font(BrutalistTheme.Typography.caption)
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                    }

                    Spacer()

                    // Trend indicator
                    trendIndicator

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                }

                // Mini chart preview
                miniChartPreview
            }
            .padding(BrutalistTheme.Spacing.lg)
            .background(BrutalistTheme.Colors.background)
            .brutalistCard()
        }
        .buttonStyle(.plain)
    }

    private var trendIndicator: some View {
        let trend = calculateTrend()
        return HStack(spacing: BrutalistTheme.Spacing.xs) {
            Image(systemName: trend.icon)
                .font(.system(size: 14, weight: .bold))
            Text(trend.label)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(trend.color)
        .padding(.horizontal, BrutalistTheme.Spacing.sm)
        .padding(.vertical, BrutalistTheme.Spacing.xs)
        .background(trend.color.opacity(0.1))
        .brutalistBorder(width: 2, color: trend.color)
    }

    private var miniChartPreview: some View {
        GeometryReader { geometry in
            let points = getMiniChartPoints(width: geometry.size.width, height: geometry.size.height)
            if points.count > 1 {
                Path { path in
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(BrutalistTheme.Colors.text, style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
            } else {
                // No data placeholder
                Text("NO DATA")
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 60)
    }

    // MARK: - Measurements List

    private var measurementsList: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
            // Header
            HStack {
                Text("MEASUREMENTS")
                    .font(BrutalistTheme.Typography.headerSmall)
                    .foregroundColor(BrutalistTheme.Colors.text)

                Spacer()

                // Export button
                Button(action: { showingExport = true }) {
                    HStack(spacing: BrutalistTheme.Spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .bold))
                        Text("EXPORT")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(BrutalistTheme.Colors.text)
                    .padding(.horizontal, BrutalistTheme.Spacing.sm)
                    .padding(.vertical, BrutalistTheme.Spacing.xs)
                    .background(BrutalistTheme.Colors.background)
                    .brutalistBorder(width: 2)
                }
                .buttonStyle(.plain)
            }

            // List
            if filteredMeasurements.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredMeasurements) { measurement in
                    MeasurementHistoryCard(measurement: measurement, filter: selectedParameter)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: BrutalistTheme.Spacing.md) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.2))

            Text("NO MEASUREMENTS")
                .font(BrutalistTheme.Typography.bodyBold)
                .foregroundColor(BrutalistTheme.Colors.text)

            Text("No data for the selected time range")
                .font(BrutalistTheme.Typography.caption)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BrutalistTheme.Spacing.xl)
        .background(BrutalistTheme.Colors.background)
        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.text.opacity(0.2))
    }

    // MARK: - Computed Properties

    private var filteredMeasurements: [Measurement] {
        let cutoff = selectedRange.startDate
        return appState.measurements.filter { measurement in
            measurement.tankId == tank.id && measurement.measuredAt >= cutoff
        }.sorted { $0.measuredAt > $1.measuredAt }
    }

    // MARK: - Helper Methods

    private func refreshData() async {
        isRefreshing = true
        await appState.fetchMeasurements(for: tank)
        isRefreshing = false
    }

    private func calculateTrend() -> (icon: String, label: String, color: Color) {
        let measurements = filteredMeasurements
        guard measurements.count >= 2 else {
            return ("minus", "STABLE", BrutalistTheme.Colors.text.opacity(0.5))
        }

        let values = getParameterValues(from: measurements)
        guard values.count >= 2 else {
            return ("minus", "STABLE", BrutalistTheme.Colors.text.opacity(0.5))
        }

        let recent = values.prefix(values.count / 2).compactMap { $0 }.average
        let older = values.suffix(values.count / 2).compactMap { $0 }.average

        guard let recentAvg = recent, let olderAvg = older else {
            return ("minus", "STABLE", BrutalistTheme.Colors.text.opacity(0.5))
        }

        let change = ((recentAvg - olderAvg) / olderAvg) * 100

        if change > 5 {
            return ("arrow.up", "UP", BrutalistTheme.Colors.warning)
        } else if change < -5 {
            return ("arrow.down", "DOWN", BrutalistTheme.Colors.action)
        } else {
            return ("minus", "STABLE", BrutalistTheme.Colors.text.opacity(0.5))
        }
    }

    private func getParameterValues(from measurements: [Measurement]) -> [Double?] {
        switch selectedParameter {
        case .all:
            return measurements.map { $0.pH }
        case .pH:
            return measurements.map { $0.pH }
        case .alkalinity:
            return measurements.map { $0.alkalinity }
        case .calcium:
            return measurements.map { $0.calcium }
        case .magnesium:
            return measurements.map { $0.magnesium }
        case .nitrate:
            return measurements.map { $0.nitrate }
        case .phosphate:
            return measurements.map { $0.phosphate }
        case .temperature:
            return measurements.map { $0.temperature }
        case .salinity:
            return measurements.map { $0.salinity }
        }
    }

    private func getMiniChartPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let values = getParameterValues(from: filteredMeasurements.reversed()).compactMap { $0 }
        guard values.count > 1 else { return [] }

        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = maxVal - minVal == 0 ? 1 : maxVal - minVal

        let padding: CGFloat = 4
        let usableWidth = width - (padding * 2)
        let usableHeight = height - (padding * 2)

        return values.enumerated().map { index, value in
            let x = padding + (CGFloat(index) / CGFloat(values.count - 1)) * usableWidth
            let y = padding + usableHeight - ((CGFloat(value - minVal) / CGFloat(range)) * usableHeight)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Date Range

enum DateRange: CaseIterable {
    case week
    case month
    case quarter
    case custom

    var displayName: String {
        switch self {
        case .week:
            return "7D"
        case .month:
            return "30D"
        case .quarter:
            return "90D"
        case .custom:
            return "ALL"
        }
    }

    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .quarter:
            return calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        case .custom:
            return Date.distantPast
        }
    }
}

// MARK: - Parameter Filter

enum ParameterFilter: CaseIterable {
    case all
    case pH
    case alkalinity
    case calcium
    case magnesium
    case nitrate
    case phosphate
    case temperature
    case salinity

    var displayName: String {
        switch self {
        case .all:
            return "ALL"
        case .pH:
            return "pH"
        case .alkalinity:
            return "ALK"
        case .calcium:
            return "CA"
        case .magnesium:
            return "MG"
        case .nitrate:
            return "NO3"
        case .phosphate:
            return "PO4"
        case .temperature:
            return "TEMP"
        case .salinity:
            return "SAL"
        }
    }
}

// MARK: - Measurement History Card

struct MeasurementHistoryCard: View {
    let measurement: Measurement
    let filter: ParameterFilter

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.sm) {
            // Date header
            HStack {
                Text(formattedDate)
                    .font(BrutalistTheme.Typography.bodyBold)
                    .foregroundColor(BrutalistTheme.Colors.text)

                Spacer()

                Text(formattedTime)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
            }

            // Parameters grid
            LazyVGrid(columns: parametersColumns, spacing: BrutalistTheme.Spacing.sm) {
                ForEach(visibleParameters, id: \.label) { param in
                    parameterCell(param)
                }
            }

            // Notes if available
            if let notes = measurement.notes, !notes.isEmpty {
                Text(notes)
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                    .padding(.top, BrutalistTheme.Spacing.xs)
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.background)
        .brutalistCard(shadowOffset: 3)
    }

    private var parametersColumns: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }

    private var visibleParameters: [(label: String, value: String, status: ParameterStatus)] {
        var params: [(label: String, value: String, status: ParameterStatus)] = []

        if filter == .all || filter == .pH {
            if let val = measurement.pH {
                params.append(("pH", String(format: "%.2f", val), ParameterRange.pH.status(for: val)))
            }
        }
        if filter == .all || filter == .alkalinity {
            if let val = measurement.alkalinity {
                params.append(("ALK", String(format: "%.1f", val), ParameterRange.alkalinity.status(for: val)))
            }
        }
        if filter == .all || filter == .calcium {
            if let val = measurement.calcium {
                params.append(("CA", String(format: "%.0f", val), ParameterRange.calcium.status(for: val)))
            }
        }
        if filter == .all || filter == .magnesium {
            if let val = measurement.magnesium {
                params.append(("MG", String(format: "%.0f", val), ParameterRange.magnesium.status(for: val)))
            }
        }
        if filter == .all || filter == .nitrate {
            if let val = measurement.nitrate {
                params.append(("NO3", String(format: "%.1f", val), ParameterRange.nitrate.status(for: val)))
            }
        }
        if filter == .all || filter == .phosphate {
            if let val = measurement.phosphate {
                params.append(("PO4", String(format: "%.2f", val), ParameterRange.phosphate.status(for: val)))
            }
        }
        if filter == .all || filter == .temperature {
            if let val = measurement.temperature {
                params.append(("TEMP", String(format: "%.1f", val), ParameterRange.temperature.status(for: val)))
            }
        }
        if filter == .all || filter == .salinity {
            if let val = measurement.salinity {
                params.append(("SAL", String(format: "%.3f", val), ParameterRange.salinity.status(for: val)))
            }
        }

        return params
    }

    private func parameterCell(_ param: (label: String, value: String, status: ParameterStatus)) -> some View {
        VStack(spacing: 2) {
            Text(param.value)
                .font(BrutalistTheme.Typography.bodyBold)
                .foregroundColor(statusColor(param.status))

            Text(param.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func statusColor(_ status: ParameterStatus) -> Color {
        switch status {
        case .optimal:
            return BrutalistTheme.Colors.text
        case .low, .high:
            return BrutalistTheme.Colors.warning
        case .unknown:
            return BrutalistTheme.Colors.text.opacity(0.5)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: measurement.measuredAt).uppercased()
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: measurement.measuredAt)
    }
}

// MARK: - Array Extension

extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

// MARK: - Preview

#Preview {
    HistoryView(tank: Tank.sample)
        .environmentObject(AppState())
}
