import Foundation
import Observation

// MARK: - Analysis Storage

/// Local persistence of saved AI analyses (`saved-analyses.json` in Application Support).
@MainActor
@Observable
final class AnalysisStorage {

    // MARK: - Properties

    /// All saved analyses, sorted by date (newest first)
    private(set) var savedAnalyses: [SavedAnalysis] = []

    /// Dates stay in Foundation's default encoding: that is how the legacy blob was written.
    @ObservationIgnored
    private var document = JSONDocument<[SavedAnalysis]>(
        file: "saved-analyses.json",
        dates: .foundationDefault,
        legacyDefaultsKey: "com.reefbuddy.savedAnalyses"
    )

    // MARK: - Initialization

    init() {
        savedAnalyses = (document.load() ?? []).sorted { $0.analyzedAt > $1.analyzedAt }
    }

    // MARK: - Public Methods

    /// Save a new analysis
    func save(_ analysis: SavedAnalysis) {
        savedAnalyses.insert(analysis, at: 0)
        persist()
    }

    /// Delete an analysis by ID
    func delete(_ id: UUID) {
        savedAnalyses.removeAll { $0.id == id }
        persist()
    }

    /// Delete multiple analyses
    func delete(_ ids: Set<UUID>) {
        savedAnalyses.removeAll { ids.contains($0.id) }
        persist()
    }

    /// Get analyses for a specific tank
    func analyses(for tankId: String) -> [SavedAnalysis] {
        savedAnalyses.filter { $0.tankId == tankId }
    }

    /// Delete all analyses for a tank
    func deleteAnalyses(for tankId: String) {
        savedAnalyses.removeAll { $0.tankId == tankId }
        persist()
    }

    /// Clear all saved analyses
    func clearAll() {
        savedAnalyses.removeAll()
        persist()
    }

    // MARK: - Private Methods

    private func persist() {
        document.save(savedAnalyses)
    }
}

// MARK: - Preview Helper

extension AnalysisStorage {
    /// Create a storage instance with sample data for previews
    static var preview: AnalysisStorage {
        let storage = AnalysisStorage()
        // Add sample data for previews if needed
        return storage
    }
}
