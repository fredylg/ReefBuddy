import Foundation

// MARK: - Tank Storage

/// Manages persistence of tanks using UserDefaults.
/// Provides local storage as fallback when backend is unavailable.
/// Thread-safe and observable for SwiftUI integration.
@MainActor
class TankStorage: ObservableObject {
    
    // MARK: - Properties
    
    /// All saved tanks
    @Published private(set) var tanks: [Tank] = []
    
    /// Key for UserDefaults storage
    private let storageKey = "com.reefbuddy.tanks"
    
    /// JSON encoder for persistence
    private let encoder: JSONEncoder
    
    /// JSON decoder for loading
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    init() {
        // Configure JSON coding
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        loadTanks()
    }
    
    // MARK: - Public Methods
    
    /// Save tanks to local storage
    func save(_ tanks: [Tank]) {
        self.tanks = tanks
        persistTanks()
    }
    
    /// Add or update a tank
    func save(_ tank: Tank) {
        if let index = tanks.firstIndex(where: { $0.id == tank.id }) {
            tanks[index] = tank
        } else {
            tanks.append(tank)
        }
        persistTanks()
    }
    
    /// Delete a tank by ID
    func delete(_ id: UUID) {
        tanks.removeAll { $0.id == id }
        persistTanks()
    }
    
    /// Get a tank by ID
    func get(_ id: UUID) -> Tank? {
        tanks.first { $0.id == id }
    }
    
    /// Clear all tanks
    func clearAll() {
        tanks.removeAll()
        persistTanks()
    }
    
    // MARK: - Private Methods
    
    /// Load tanks from UserDefaults
    private func loadTanks() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            tanks = []
            return
        }
        
        do {
            tanks = try decoder.decode([Tank].self, from: data)
            print("📦 Loaded \(tanks.count) tanks from local storage")
        } catch {
            print("⚠️ Failed to load tanks from local storage: \(error.localizedDescription)")
            tanks = []
        }
    }
    
    /// Persist tanks to UserDefaults
    private func persistTanks() {
        do {
            let data = try encoder.encode(tanks)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("💾 Saved \(tanks.count) tanks to local storage")
        } catch {
            print("⚠️ Failed to save tanks to local storage: \(error.localizedDescription)")
        }
    }
}
