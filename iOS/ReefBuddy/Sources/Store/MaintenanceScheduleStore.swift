import Foundation

// MARK: - Maintenance Schedule Store (local-first)

@MainActor
final class MaintenanceScheduleStore: ObservableObject {
    @Published private(set) var schedules: [MaintenanceSchedule] = []

    private let storageKey = "com.reefbuddy.maintenance_schedules"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private let apiClient = APIClient()

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    // MARK: - Public API

    var activeSchedules: [MaintenanceSchedule] {
        schedules
            .filter { !$0.isDeleted }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func upsertLocal(_ schedule: MaintenanceSchedule) {
        var updated = schedule
        updated.updatedAt = Date()
        updated.needsSync = true
        updated.isDeleted = false

        if let idx = schedules.firstIndex(where: { $0.id == updated.id }) {
            schedules[idx] = updated
        } else {
            schedules.append(updated)
        }
        persist()
    }

    func setEnabled(_ enabled: Bool, for scheduleId: UUID) {
        guard let idx = schedules.firstIndex(where: { $0.id == scheduleId }) else { return }
        schedules[idx].enabled = enabled
        schedules[idx].updatedAt = Date()
        schedules[idx].needsSync = true
        persist()
    }

    func markDeleted(_ scheduleId: UUID) {
        guard let idx = schedules.firstIndex(where: { $0.id == scheduleId }) else { return }
        schedules[idx].enabled = false
        schedules[idx].isDeleted = true
        schedules[idx].updatedAt = Date()
        schedules[idx].needsSync = true
        persist()
    }

    func schedule(with id: UUID) -> MaintenanceSchedule? {
        schedules.first(where: { $0.id == id })
    }

    /// Best-effort sync for any items marked `needsSync`.
    func syncPendingBestEffort() async {
        let pending = schedules.filter { $0.needsSync }
        print("☁️ [ScheduleStore] syncPendingBestEffort — \(pending.count) pending of \(schedules.count) total")
        guard !pending.isEmpty else { return }

        for item in pending {
            do {
                if item.isDeleted {
                    print("☁️ [ScheduleStore] deleting \(item.id)")
                    try await apiClient.deleteMaintenanceSchedule(id: item.id)
                    schedules.removeAll { $0.id == item.id }
                    persist()
                } else {
                    do {
                        print("☁️ [ScheduleStore] updating \(item.id)")
                        _ = try await apiClient.updateMaintenanceSchedule(item)
                    } catch APIError.notFound {
                        print("☁️ [ScheduleStore] not found → creating \(item.id)")
                        _ = try await apiClient.createMaintenanceSchedule(item)
                    }
                    markSynced(item.id)
                    print("☁️ [ScheduleStore] synced \(item.id)")
                }
            } catch {
                print("⚠️ [ScheduleStore] sync failed for \(item.id): \(error)")
            }
        }
    }

    func markSynced(_ id: UUID) {
        guard let idx = schedules.firstIndex(where: { $0.id == id }) else { return }
        schedules[idx].needsSync = false
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            schedules = []
            return
        }

        do {
            schedules = try decoder.decode([MaintenanceSchedule].self, from: data)
            print("📦 Loaded \(schedules.count) maintenance schedules from local storage")
        } catch {
            print("⚠️ Failed to load maintenance schedules: \(error.localizedDescription)")
            schedules = []
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(schedules)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("⚠️ Failed to persist maintenance schedules: \(error.localizedDescription)")
        }
    }
}

// MARK: - Water Change Store (local-first)

@MainActor
final class WaterChangeStorage: ObservableObject {
    @Published private(set) var waterChangesByTank: [UUID: [WaterChange]] = [:]

    private let storageKey = "com.reefbuddy.water_changes"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    func waterChanges(for tankId: UUID) -> [WaterChange] {
        (waterChangesByTank[tankId] ?? [])
            .filter { !$0.isDeleted }
            .sorted { $0.performedAt > $1.performedAt }
    }

    func replace(_ waterChanges: [WaterChange], for tankId: UUID) {
        waterChangesByTank[tankId] = waterChanges.sorted { $0.performedAt > $1.performedAt }
        persist()
    }

    func save(_ waterChange: WaterChange) {
        var entries = waterChangesByTank[waterChange.tankId] ?? []
        if let index = entries.firstIndex(where: { $0.id == waterChange.id }) {
            entries[index] = waterChange
        } else {
            entries.insert(waterChange, at: 0)
        }
        waterChangesByTank[waterChange.tankId] = entries.sorted { $0.performedAt > $1.performedAt }
        persist()
    }

    func markDeleted(_ id: UUID, tankId: UUID) {
        guard var entries = waterChangesByTank[tankId],
              let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isDeleted = true
        entries[index].needsSync = true
        entries[index].updatedAt = Date()
        waterChangesByTank[tankId] = entries
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            waterChangesByTank = [:]
            return
        }

        do {
            let stringDict = try decoder.decode([String: [WaterChange]].self, from: data)
            waterChangesByTank = Dictionary(uniqueKeysWithValues:
                stringDict.compactMap { key, value in
                    guard let uuid = UUID(uuidString: key) else { return nil }
                    return (uuid, value)
                }
            )
            let total = waterChangesByTank.values.reduce(0) { $0 + $1.count }
            print("📦 Loaded \(total) water changes from local storage")
        } catch {
            print("⚠️ Failed to load water changes: \(error.localizedDescription)")
            waterChangesByTank = [:]
        }
    }

    private func persist() {
        do {
            let stringDict = Dictionary(uniqueKeysWithValues:
                waterChangesByTank.map { ($0.key.uuidString, $0.value) }
            )
            let data = try encoder.encode(stringDict)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("⚠️ Failed to persist water changes: \(error.localizedDescription)")
        }
    }
}

