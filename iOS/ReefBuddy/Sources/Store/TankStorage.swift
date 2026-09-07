import Foundation
import Observation

// MARK: - Tank Storage

/// Local persistence of tanks (`tanks.json` in Application Support).
/// Provides local storage as fallback when backend is unavailable.
@MainActor
@Observable
final class TankStorage {

    // MARK: - Properties

    /// All saved tanks
    private(set) var tanks: [Tank] = []

    @ObservationIgnored
    private var document = JSONDocument<[Tank]>(file: "tanks.json", legacyDefaultsKey: "com.reefbuddy.tanks")

    // MARK: - Initialization

    init() {
        tanks = document.load() ?? []
        debugLog("📦 Loaded \(tanks.count) tanks from local storage")
    }

    // MARK: - Public Methods

    /// Save tanks to local storage
    func save(_ tanks: [Tank]) {
        self.tanks = tanks
        persist()
    }

    /// Add or update a tank
    func save(_ tank: Tank) {
        if let index = tanks.firstIndex(where: { $0.id == tank.id }) {
            tanks[index] = tank
        } else {
            tanks.append(tank)
        }
        persist()
    }

    /// Delete a tank by ID
    func delete(_ id: UUID) {
        tanks.removeAll { $0.id == id }
        persist()
    }

    /// Get a tank by ID
    func get(_ id: UUID) -> Tank? {
        tanks.first { $0.id == id }
    }

    /// Clear all tanks
    func clearAll() {
        tanks.removeAll()
        persist()
    }

    // MARK: - Private Methods

    private func persist() {
        document.save(tanks)
    }
}
