import Foundation
import Observation

// MARK: - Livestock Storage

/// Local persistence of livestock and livestock logs (JSON documents in Application Support).
/// Provides local storage as fallback when backend is unavailable.
/// Thread-safe and observable for SwiftUI integration.
@MainActor
@Observable
final class LivestockStorage {
    
    // MARK: - Properties
    
    /// All saved livestock
    private(set) var livestock: [Livestock] = []
    
    /// All saved livestock logs
    private(set) var livestockLogs: [LivestockLog] = []
    
    /// Documents in Application Support (photos live in ImageStorage, not in the JSON).
    @ObservationIgnored
    private var livestockDocument = JSONDocument<[Livestock]>(
        file: "livestock.json",
        legacyDefaultsKey: "com.reefbuddy.livestock"
    )
    @ObservationIgnored
    private var logsDocument = JSONDocument<[LivestockLog]>(
        file: "livestock-logs.json",
        legacyDefaultsKey: "com.reefbuddy.livestockLogs"
    )
    
    
    /// Image storage for livestock photos
    private let imageStorage = ImageStorage()
    
    // MARK: - Initialization
    
    init() {
        loadLivestock()
        loadLogs()
    }
    
    // MARK: - Livestock Methods
    
    /// Save all livestock
    func save(_ livestock: [Livestock]) {
        self.livestock = livestock
        persistLivestock()
    }
    
    /// Add or update a livestock item
    func save(_ item: Livestock) {
        if let index = livestock.firstIndex(where: { $0.id == item.id }) {
            livestock[index] = item
        } else {
            livestock.append(item)
        }
        persistLivestock()
    }
    
    /// Delete livestock by ID
    func deleteLivestock(_ id: UUID) {
        // Delete image from file system
        imageStorage.deleteImage(for: id)
        
        livestock.removeAll { $0.id == id }
        // Also remove related logs
        let relatedLogIds = livestockLogs.filter { $0.livestockId == id }.map { $0.id }
        livestockLogs.removeAll { $0.livestockId == id }
        
        // Delete images for related logs
        for logId in relatedLogIds {
            imageStorage.deleteImage(for: logId)
        }
        
        persistLivestock()
        persistLogs()
    }
    
    /// Get livestock for a specific tank
    func livestock(for tankId: UUID) -> [Livestock] {
        livestock.filter { $0.tankId == tankId }
    }

    /// Get logs for livestock in a specific tank
    func livestockLogs(for tankId: UUID) -> [LivestockLog] {
        let tankLivestockIds = livestock.filter { $0.tankId == tankId }.map { $0.id }
        return livestockLogs.filter { tankLivestockIds.contains($0.livestockId) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }
    
    // MARK: - Livestock Log Methods
    
    /// Save all logs
    func saveLogs(_ logs: [LivestockLog]) {
        self.livestockLogs = logs
        persistLogs()
    }
    
    /// Add or update a log entry
    /// Ensures no duplicates by ID - if a log with the same ID exists, it's updated; otherwise inserted
    func saveLog(_ log: LivestockLog) {
        // Remove any existing log with the same ID to prevent duplicates
        livestockLogs.removeAll { $0.id == log.id }
        // Insert the log at the beginning (newest first)
        livestockLogs.insert(log, at: 0)
        persistLogs()
    }
    
    /// Delete log by ID
    func deleteLog(_ id: UUID) {
        // Delete image from file system
        imageStorage.deleteImage(for: id)
        
        livestockLogs.removeAll { $0.id == id }
        persistLogs()
    }
    
    /// Get logs for specific livestock
    func logs(for livestockId: UUID) -> [LivestockLog] {
        livestockLogs.filter { $0.livestockId == livestockId }
            .sorted { $0.loggedAt > $1.loggedAt }
    }
    
    /// Clear all data
    func clearAll() {
        livestock.removeAll()
        livestockLogs.removeAll()
        persistLivestock()
        persistLogs()
    }
    
    // MARK: - Private Methods

    /// Load livestock from the document, then attach photos from the file system.
    private func loadLivestock() {
        var loaded = livestockDocument.load() ?? []
        for index in loaded.indices {
            if let imageData = imageStorage.loadImage(for: loaded[index].id) {
                loaded[index].photoData = imageData
            }
        }
        livestock = loaded
        debugLog("📦 Loaded \(livestock.count) livestock items from local storage")
    }

    /// Persist livestock; photos go to the file system, the JSON excludes `photoData` via CodingKeys.
    private func persistLivestock() {
        for item in livestock {
            if let photoData = item.photoData {
                _ = imageStorage.saveImage(photoData, for: item.id)
            }
        }
        livestockDocument.save(livestock)
    }

    /// Load logs from the document, then attach photos from the file system.
    private func loadLogs() {
        var loaded = logsDocument.load() ?? []
        for index in loaded.indices {
            if let imageData = imageStorage.loadImage(for: loaded[index].id) {
                loaded[index].photoData = imageData
            }
        }
        livestockLogs = loaded
        debugLog("📦 Loaded \(livestockLogs.count) livestock logs from local storage")
    }

    /// Persist logs; photos go to the file system, the JSON excludes `photoData` via CodingKeys.
    private func persistLogs() {
        for log in livestockLogs {
            if let photoData = log.photoData {
                _ = imageStorage.saveImage(photoData, for: log.id)
            }
        }
        logsDocument.save(livestockLogs)
    }
}
