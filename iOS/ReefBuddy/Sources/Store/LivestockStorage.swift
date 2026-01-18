import Foundation

// MARK: - Livestock Storage

/// Manages persistence of livestock and livestock logs using UserDefaults.
/// Provides local storage as fallback when backend is unavailable.
/// Thread-safe and observable for SwiftUI integration.
@MainActor
class LivestockStorage: ObservableObject {
    
    // MARK: - Properties
    
    /// All saved livestock
    @Published private(set) var livestock: [Livestock] = []
    
    /// All saved livestock logs
    @Published private(set) var livestockLogs: [LivestockLog] = []
    
    /// Key for UserDefaults storage
    private let livestockKey = "com.reefbuddy.livestock"
    private let logsKey = "com.reefbuddy.livestockLogs"
    
    /// JSON encoder for persistence
    private let encoder: JSONEncoder
    
    /// JSON decoder for loading
    private let decoder: JSONDecoder
    
    /// Image storage for livestock photos
    private let imageStorage = ImageStorage()
    
    // MARK: - Initialization
    
    init() {
        // Configure JSON coding
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
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
    
    // MARK: - Livestock Log Methods
    
    /// Save all logs
    func saveLogs(_ logs: [LivestockLog]) {
        self.livestockLogs = logs
        persistLogs()
    }
    
    /// Add or update a log entry
    func saveLog(_ log: LivestockLog) {
        if let index = livestockLogs.firstIndex(where: { $0.id == log.id }) {
            livestockLogs[index] = log
        } else {
            livestockLogs.insert(log, at: 0) // Newest first
        }
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
    
    /// Load livestock from UserDefaults
    /// Also loads images from file system
    private func loadLivestock() {
        guard let data = UserDefaults.standard.data(forKey: livestockKey) else {
            livestock = []
            return
        }
        
        do {
            var loadedLivestock = try decoder.decode([Livestock].self, from: data)
            
            // Load images from file system for each livestock item (prefer file system over encoded Data)
            for index in loadedLivestock.indices {
                if let imageData = imageStorage.loadImage(for: loadedLivestock[index].id) {
                    loadedLivestock[index].photoData = imageData
                }
                // If file system doesn't have it, keep the decoded photoData (if any)
            }
            
            livestock = loadedLivestock
            print("📦 Loaded \(livestock.count) livestock items from local storage")
        } catch {
            print("⚠️ Failed to load livestock from local storage: \(error.localizedDescription)")
            livestock = []
        }
    }
    
    /// Persist livestock to UserDefaults
    /// Also saves images to file system separately
    private func persistLivestock() {
        do {
            // Save images to file system for each livestock item
            for item in livestock {
                if let photoData = item.photoData {
                    imageStorage.saveImage(photoData, for: item.id)
                }
            }
            
            // Encode livestock (photoData is included but also saved separately to file system)
            let data = try encoder.encode(livestock)
            UserDefaults.standard.set(data, forKey: livestockKey)
            print("💾 Saved \(livestock.count) livestock items to local storage")
        } catch {
            print("⚠️ Failed to save livestock to local storage: \(error.localizedDescription)")
        }
    }
    
    /// Load logs from UserDefaults
    /// Also loads images from file system
    private func loadLogs() {
        guard let data = UserDefaults.standard.data(forKey: logsKey) else {
            livestockLogs = []
            return
        }
        
        do {
            var loadedLogs = try decoder.decode([LivestockLog].self, from: data)
            
            // Load images from file system for each log entry (prefer file system over encoded Data)
            for index in loadedLogs.indices {
                if let imageData = imageStorage.loadImage(for: loadedLogs[index].id) {
                    loadedLogs[index].photoData = imageData
                }
                // If file system doesn't have it, keep the decoded photoData (if any)
            }
            
            livestockLogs = loadedLogs
            print("📦 Loaded \(livestockLogs.count) livestock logs from local storage")
        } catch {
            print("⚠️ Failed to load livestock logs from local storage: \(error.localizedDescription)")
            livestockLogs = []
        }
    }
    
    /// Persist logs to UserDefaults
    /// Also saves images to file system separately
    private func persistLogs() {
        do {
            // Save images to file system for each log entry
            for log in livestockLogs {
                if let photoData = log.photoData {
                    imageStorage.saveImage(photoData, for: log.id)
                }
            }
            
            // Encode logs (photoData is included but also saved separately to file system)
            let data = try encoder.encode(livestockLogs)
            UserDefaults.standard.set(data, forKey: logsKey)
            print("💾 Saved \(livestockLogs.count) livestock logs to local storage")
        } catch {
            print("⚠️ Failed to save livestock logs to local storage: \(error.localizedDescription)")
        }
    }
}
