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
        guard !pending.isEmpty else { return }

        for item in pending {
            do {
                if item.isDeleted {
                    try await apiClient.deleteMaintenanceSchedule(id: item.id)
                    schedules.removeAll { $0.id == item.id }
                    persist()
                } else {
                    do {
                        _ = try await apiClient.updateMaintenanceSchedule(item)
                    } catch APIError.notFound {
                        _ = try await apiClient.createMaintenanceSchedule(item)
                    }
                    markSynced(item.id)
                }
            } catch {
                // Keep local state + notifications working; retry later
                print("⚠️ Maintenance sync failed for \(item.id): \(error.localizedDescription)")
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

