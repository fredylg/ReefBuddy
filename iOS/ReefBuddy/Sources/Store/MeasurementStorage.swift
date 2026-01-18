import Foundation

// MARK: - Measurement Storage

/// Manages persistence of measurements using UserDefaults.
/// Provides local storage as fallback when backend is unavailable.
/// Thread-safe and observable for SwiftUI integration.
@MainActor
class MeasurementStorage: ObservableObject {
    
    // MARK: - Properties
    
    /// All saved measurements, organized by tank ID
    @Published private(set) var measurements: [UUID: [Measurement]] = [:]
    
    /// Key for UserDefaults storage
    private let storageKey = "com.reefbuddy.measurements"
    
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
        
        loadMeasurements()
    }
    
    // MARK: - Public Methods
    
    /// Get measurements for a specific tank
    func measurements(for tankId: UUID) -> [Measurement] {
        measurements[tankId] ?? []
    }
    
    /// Save measurements for a tank
    func save(_ measurements: [Measurement], for tankId: UUID) {
        self.measurements[tankId] = measurements
        persistMeasurements()
    }
    
    /// Add or update a measurement
    func save(_ measurement: Measurement) {
        let tankId = measurement.tankId
        var tankMeasurements = measurements[tankId] ?? []
        
        if let index = tankMeasurements.firstIndex(where: { $0.id == measurement.id }) {
            tankMeasurements[index] = measurement
        } else {
            tankMeasurements.insert(measurement, at: 0) // Newest first
        }
        
        measurements[tankId] = tankMeasurements
        persistMeasurements()
    }
    
    /// Delete a measurement by ID
    func delete(_ id: UUID, from tankId: UUID) {
        guard var tankMeasurements = measurements[tankId] else { return }
        tankMeasurements.removeAll { $0.id == id }
        measurements[tankId] = tankMeasurements.isEmpty ? nil : tankMeasurements
        persistMeasurements()
    }
    
    /// Delete all measurements for a tank
    func deleteAll(for tankId: UUID) {
        measurements.removeValue(forKey: tankId)
        persistMeasurements()
    }
    
    /// Clear all measurements
    func clearAll() {
        measurements.removeAll()
        persistMeasurements()
    }
    
    // MARK: - Private Methods
    
    /// Load measurements from UserDefaults
    private func loadMeasurements() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            measurements = [:]
            return
        }
        
        do {
            // Decode as dictionary with UUID keys as strings
            let stringDict = try decoder.decode([String: [Measurement]].self, from: data)
            // Convert string keys to UUID
            measurements = Dictionary(uniqueKeysWithValues: 
                stringDict.compactMap { key, value in
                    guard let uuid = UUID(uuidString: key) else { return nil }
                    return (uuid, value)
                }
            )
            let totalCount = measurements.values.reduce(0) { $0 + $1.count }
            print("📦 Loaded \(totalCount) measurements from local storage")
        } catch {
            print("⚠️ Failed to load measurements from local storage: \(error.localizedDescription)")
            measurements = [:]
        }
    }
    
    /// Persist measurements to UserDefaults
    private func persistMeasurements() {
        do {
            // Convert UUID keys to strings for encoding
            let stringDict = Dictionary(uniqueKeysWithValues:
                measurements.map { ($0.key.uuidString, $0.value) }
            )
            let data = try encoder.encode(stringDict)
            UserDefaults.standard.set(data, forKey: storageKey)
            let totalCount = measurements.values.reduce(0) { $0 + $1.count }
            print("💾 Saved \(totalCount) measurements to local storage")
        } catch {
            print("⚠️ Failed to save measurements to local storage: \(error.localizedDescription)")
        }
    }
}
