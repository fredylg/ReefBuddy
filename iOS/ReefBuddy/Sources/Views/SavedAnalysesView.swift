import SwiftUI

// MARK: - Saved Analyses View

/// Displays all saved AI analyses with filtering by tank.
/// New Brutalist style: high contrast, sharp edges, bold typography.
struct SavedAnalysesView: View {
    
    // MARK: - Properties
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var analysisStorage: AnalysisStorage
    @State private var selectedTankFilter: String? = nil
    @State private var showingDeleteConfirmation = false
    @State private var analysisToDelete: SavedAnalysis?
    @State private var expandedAnalysisId: UUID?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Filter Bar
            if !appState.tanks.isEmpty {
                filterBar
            }
            
            // Content
            if filteredAnalyses.isEmpty {
                emptyState
            } else {
                analysesList
            }
        }
        .background(BrutalistTheme.Colors.background)
        .alert("DELETE ANALYSIS", isPresented: $showingDeleteConfirmation) {
            Button("CANCEL", role: .cancel) {
                analysisToDelete = nil
            }
            Button("DELETE", role: .destructive) {
                if let analysis = analysisToDelete {
                    withAnimation {
                        analysisStorage.delete(analysis.id)
                    }
                    analysisToDelete = nil
                }
            }
        } message: {
            Text("This analysis will be permanently deleted.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredAnalyses: [SavedAnalysis] {
        if let tankId = selectedTankFilter {
            return analysisStorage.analyses(for: tankId)
        }
        return analysisStorage.savedAnalyses
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                Text("SAVED ANALYSES")
                    .font(BrutalistTheme.Typography.headerMedium)
                    .foregroundColor(BrutalistTheme.Colors.text)
                
                Text("\(filteredAnalyses.count) saved")
                    .font(BrutalistTheme.Typography.caption)
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
            }
            
            Spacer()
            
            // Analysis count badge
            Text("\(analysisStorage.savedAnalyses.count)")
                .font(BrutalistTheme.Typography.headerMedium)
                .foregroundColor(BrutalistTheme.Colors.action)
                .padding(.horizontal, BrutalistTheme.Spacing.sm)
                .padding(.vertical, BrutalistTheme.Spacing.xs)
                .background(BrutalistTheme.Colors.background)
                .brutalistBorder(width: 2)
        }
        .padding(BrutalistTheme.Spacing.lg)
        .background(BrutalistTheme.Colors.background)
        .overlay(
            Rectangle()
                .fill(BrutalistTheme.Colors.text)
                .frame(height: BrutalistTheme.Borders.standard),
            alignment: .bottom
        )
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrutalistTheme.Spacing.sm) {
                // All filter
                filterButton(title: "ALL", isSelected: selectedTankFilter == nil) {
                    withAnimation { selectedTankFilter = nil }
                }
                
                // Tank filters
                ForEach(appState.tanks) { tank in
                    filterButton(
                        title: tank.name.uppercased(),
                        isSelected: selectedTankFilter == tank.id
                    ) {
                        withAnimation {
                            selectedTankFilter = selectedTankFilter == tank.id ? nil : tank.id
                        }
                    }
                }
            }
            .padding(.horizontal, BrutalistTheme.Spacing.lg)
            .padding(.vertical, BrutalistTheme.Spacing.md)
        }
        .background(BrutalistTheme.Colors.text.opacity(0.03))
    }
    
    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? BrutalistTheme.Colors.text : BrutalistTheme.Colors.text.opacity(0.5))
                .padding(.horizontal, BrutalistTheme.Spacing.md)
                .padding(.vertical, BrutalistTheme.Spacing.sm)
                .background(isSelected ? BrutalistTheme.Colors.action : BrutalistTheme.Colors.background)
                .brutalistBorder(width: isSelected ? 3 : 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: BrutalistTheme.Spacing.lg) {
            Spacer()
            
            // Icon
            ZStack {
                Rectangle()
                    .fill(BrutalistTheme.Colors.text.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .brutalistBorder(width: 2)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(BrutalistTheme.Colors.text.opacity(0.3))
            }
            
            Text("NO SAVED ANALYSES")
                .font(BrutalistTheme.Typography.headerSmall)
                .foregroundColor(BrutalistTheme.Colors.text)
            
            Text("Analyses you save will appear here.\nRun an analysis and tap 'Save' to keep it.")
                .font(BrutalistTheme.Typography.body)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(BrutalistTheme.Spacing.xl)
    }
    
    // MARK: - Analyses List
    
    private var analysesList: some View {
        ScrollView {
            LazyVStack(spacing: BrutalistTheme.Spacing.md) {
                ForEach(filteredAnalyses) { analysis in
                    analysisCard(analysis)
                }
            }
            .padding(BrutalistTheme.Spacing.lg)
        }
    }
    
    // MARK: - Analysis Card
    
    private func analysisCard(_ analysis: SavedAnalysis) -> some View {
        let isExpanded = expandedAnalysisId == analysis.id
        
        return VStack(spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedAnalysisId = isExpanded ? nil : analysis.id
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                        Text(analysis.tankName.uppercased())
                            .font(BrutalistTheme.Typography.bodyBold)
                            .foregroundColor(BrutalistTheme.Colors.text)
                        
                        Text(formattedDate(analysis.analyzedAt))
                            .font(BrutalistTheme.Typography.caption)
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Warning indicator
                    if let warnings = analysis.warnings, !warnings.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(BrutalistTheme.Colors.warning)
                            .padding(.trailing, BrutalistTheme.Spacing.sm)
                    }
                    
                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(BrutalistTheme.Colors.text)
                }
                .padding(BrutalistTheme.Spacing.md)
                .background(BrutalistTheme.Colors.background)
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.md) {
                    // Divider
                    Rectangle()
                        .fill(BrutalistTheme.Colors.text)
                        .frame(height: 2)
                    
                    // Summary
                    VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                        Text("SUMMARY")
                            .font(BrutalistTheme.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                        
                        Text(analysis.summary)
                            .font(BrutalistTheme.Typography.body)
                            .foregroundColor(BrutalistTheme.Colors.text)
                    }
                    
                    // Warnings
                    if let warnings = analysis.warnings, !warnings.isEmpty {
                        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                            Text("⚠️ WARNINGS")
                                .font(BrutalistTheme.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(BrutalistTheme.Colors.warning)
                            
                            ForEach(warnings, id: \.self) { warning in
                                HStack(alignment: .top, spacing: BrutalistTheme.Spacing.sm) {
                                    Text("•")
                                        .foregroundColor(BrutalistTheme.Colors.warning)
                                    Text(warning)
                                        .font(BrutalistTheme.Typography.body)
                                        .foregroundColor(BrutalistTheme.Colors.text)
                                }
                            }
                        }
                        .padding(BrutalistTheme.Spacing.md)
                        .background(BrutalistTheme.Colors.warning.opacity(0.1))
                        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.warning)
                    }
                    
                    // Recommendations
                    if !analysis.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                            Text("RECOMMENDATIONS")
                                .font(BrutalistTheme.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
                            
                            ForEach(analysis.recommendations, id: \.self) { rec in
                                HStack(alignment: .top, spacing: BrutalistTheme.Spacing.sm) {
                                    Text("→")
                                        .foregroundColor(BrutalistTheme.Colors.action)
                                    Text(rec)
                                        .font(BrutalistTheme.Typography.body)
                                        .foregroundColor(BrutalistTheme.Colors.text)
                                }
                            }
                        }
                    }
                    
                    // Dosing Advice
                    if let dosing = analysis.dosingAdvice, !dosing.isEmpty {
                        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
                            Text("DOSING ADVICE")
                                .font(BrutalistTheme.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(BrutalistTheme.Colors.action)
                            
                            Text(dosing)
                                .font(BrutalistTheme.Typography.body)
                                .foregroundColor(BrutalistTheme.Colors.text)
                        }
                        .padding(BrutalistTheme.Spacing.md)
                        .background(BrutalistTheme.Colors.action.opacity(0.1))
                        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.action)
                    }
                    
                    // Parameters snapshot
                    parametersSection(analysis.parameters)
                    
                    // Delete button
                    Button(action: {
                        analysisToDelete = analysis
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                            Text("DELETE")
                                .font(BrutalistTheme.Typography.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(BrutalistTheme.Colors.warning)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BrutalistTheme.Spacing.sm)
                        .background(BrutalistTheme.Colors.warning.opacity(0.1))
                        .brutalistBorder(width: 2, color: BrutalistTheme.Colors.warning)
                    }
                    .buttonStyle(.plain)
                }
                .padding(BrutalistTheme.Spacing.md)
            }
        }
        .background(BrutalistTheme.Colors.background)
        .brutalistBorder()
        .brutalistShadow(offset: isExpanded ? 6 : 4)
    }
    
    // MARK: - Parameters Section
    
    private func parametersSection(_ params: AnalyzedParameters) -> some View {
        VStack(alignment: .leading, spacing: BrutalistTheme.Spacing.xs) {
            Text("PARAMETERS AT TIME OF ANALYSIS")
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: BrutalistTheme.Spacing.sm) {
                if let sal = params.salinity { parameterCell("Salinity", "\(String(format: "%.3f", sal))") }
                if let temp = params.temperature { parameterCell("Temp", "\(String(format: "%.1f", temp))°F") }
                if let ph = params.ph { parameterCell("pH", "\(String(format: "%.2f", ph))") }
                if let alk = params.alkalinity { parameterCell("Alk", "\(String(format: "%.1f", alk)) dKH") }
                if let cal = params.calcium { parameterCell("Ca", "\(Int(cal)) ppm") }
                if let mag = params.magnesium { parameterCell("Mg", "\(Int(mag)) ppm") }
                if let no3 = params.nitrate { parameterCell("NO₃", "\(String(format: "%.1f", no3)) ppm") }
                if let no2 = params.nitrite { parameterCell("NO₂", "\(String(format: "%.2f", no2)) ppm") }
                if let nh3 = params.ammonia { parameterCell("NH₃", "\(String(format: "%.2f", nh3)) ppm") }
                if let po4 = params.phosphate { parameterCell("PO₄", "\(String(format: "%.2f", po4)) ppm") }
            }
        }
        .padding(BrutalistTheme.Spacing.md)
        .background(BrutalistTheme.Colors.text.opacity(0.03))
        .brutalistBorder(width: 2)
    }
    
    private func parameterCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(BrutalistTheme.Colors.text.opacity(0.5))
            Text(value)
                .font(BrutalistTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(BrutalistTheme.Colors.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BrutalistTheme.Spacing.xs)
    }
    
    // MARK: - Helpers
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    SavedAnalysesView()
        .environmentObject(AppState())
        .environmentObject(AnalysisStorage())
}
