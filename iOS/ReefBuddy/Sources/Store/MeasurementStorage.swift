import Foundation
import Observation

// MARK: - Measurement Storage

/// Local persistence of measurements (`measurements.json` in Application Support), keyed by tank.
/// Provides local storage as fallback when backend is unavailable.
@MainActor
@Observable
final class MeasurementStorage {

    // MARK: - Properties

    /// All saved measurements, organized by tank ID
    private(set) var measurements: [UUID: [Measurement]] = [:]

    /// The document keeps string keys: JSON objects need string keys and the legacy blob was written that way.
    @ObservationIgnored
    private var document = JSONDocument<[String: [Measurement]]>(
        file: "measurements.json",
        legacyDefaultsKey: "com.reefbuddy.measurements"
    )

    // MARK: - Initialization

    init() {
        let stored = document.load() ?? [:]
        measurements = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value) }
        })
        let totalCount = measurements.values.reduce(0) { $0 + $1.count }
        debugLog("📦 Loaded \(totalCount) measurements from local storage")
    }

    // MARK: - Public Methods

    /// Get measurements for a specific tank
    func measurements(for tankId: UUID) -> [Measurement] {
        measurements[tankId] ?? []
    }

    /// Save measurements for a tank
    func save(_ measurements: [Measurement], for tankId: UUID) {
        self.measurements[tankId] = measurements
        persist()
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
        persist()
    }

    /// Delete a measurement by ID
    func delete(_ id: UUID, from tankId: UUID) {
        guard var tankMeasurements = measurements[tankId] else { return }
        tankMeasurements.removeAll { $0.id == id }
        measurements[tankId] = tankMeasurements.isEmpty ? nil : tankMeasurements
        persist()
    }

    /// Delete all measurements for a tank
    func deleteAll(for tankId: UUID) {
        measurements.removeValue(forKey: tankId)
        persist()
    }

    /// Clear all measurements
    func clearAll() {
        measurements.removeAll()
        persist()
    }

    // MARK: - Private Methods

    private func persist() {
        document.save(Dictionary(uniqueKeysWithValues: measurements.map { ($0.key.uuidString, $0.value) }))
    }
}
