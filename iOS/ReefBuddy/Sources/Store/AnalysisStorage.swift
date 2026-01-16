import Foundation

// MARK: - Analysis Storage

/// Manages persistence of saved AI analyses using UserDefaults.
/// Thread-safe and observable for SwiftUI integration.
@MainActor
class AnalysisStorage: ObservableObject {
    
    // MARK: - Properties
    
    /// All saved analyses, sorted by date (newest first)
    @Published private(set) var savedAnalyses: [SavedAnalysis] = []
    
    /// Key for UserDefaults storage
    private let storageKey = "com.reefbuddy.savedAnalyses"
    
    /// JSON encoder for persistence
    private let encoder = JSONEncoder()
    
    /// JSON decoder for loading
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    init() {
        loadAnalyses()
    }
    
    // MARK: - Public Methods
    
    /// Save a new analysis
    func save(_ analysis: SavedAnalysis) {
        savedAnalyses.insert(analysis, at: 0)
        persistAnalyses()
    }
    
    /// Delete an analysis by ID
    func delete(_ id: UUID) {
        savedAnalyses.removeAll { $0.id == id }
        persistAnalyses()
    }
    
    /// Delete multiple analyses
    func delete(_ ids: Set<UUID>) {
        savedAnalyses.removeAll { ids.contains($0.id) }
        persistAnalyses()
    }
    
    /// Get analyses for a specific tank
    func analyses(for tankId: String) -> [SavedAnalysis] {
        savedAnalyses.filter { $0.tankId == tankId }
    }
    
    /// Delete all analyses for a tank
    func deleteAnalyses(for tankId: String) {
        savedAnalyses.removeAll { $0.tankId == tankId }
        persistAnalyses()
    }
    
    /// Clear all saved analyses
    func clearAll() {
        savedAnalyses.removeAll()
        persistAnalyses()
    }
    
    // MARK: - Private Methods
    
    /// Load analyses from UserDefaults
    private func loadAnalyses() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            savedAnalyses = []
            return
        }
        
        do {
            savedAnalyses = try decoder.decode([SavedAnalysis].self, from: data)
            // Sort by date, newest first
            savedAnalyses.sort { $0.analyzedAt > $1.analyzedAt }
        } catch {
            print("Error loading saved analyses: \(error)")
            savedAnalyses = []
        }
    }
    
    /// Persist analyses to UserDefaults
    private func persistAnalyses() {
        do {
            let data = try encoder.encode(savedAnalyses)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Error saving analyses: \(error)")
        }
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
