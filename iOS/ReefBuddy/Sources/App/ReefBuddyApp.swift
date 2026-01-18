import SwiftUI
import UIKit

// MARK: - ReefBuddy App

/// Main entry point for the ReefBuddy iOS application.
/// Built with New Brutalist design principles: bold, high-contrast, no compromises.
@main
struct ReefBuddyApp: App {

    // MARK: - State

    @StateObject private var storeManager = StoreManager()
    @StateObject private var analysisStorage = AnalysisStorage()
    @StateObject private var appState: AppState

    init() {
        _appState = StateObject(wrappedValue: AppState())
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(storeManager)
                .environmentObject(analysisStorage)
        }
    }
}

// MARK: - App State

/// Global application state manager
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published Properties

    /// All user tanks
    @Published var tanks: [Tank] = []

    /// Currently selected tank
    @Published var selectedTank: Tank?

    /// Measurements for the selected tank
    @Published var measurements: [Measurement] = []

    /// Livestock for the selected tank
    @Published var livestock: [Livestock] = []

    /// Health logs for livestock
    @Published var livestockLogs: [LivestockLog] = []

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Show purchase credits sheet when user runs out of credits
    @Published var showPurchaseCredits: Bool = false

    // MARK: - Dependencies

    private let apiClient = APIClient()
    private let tankStorage = TankStorage()
    private let livestockStorage = LivestockStorage()
    private let measurementStorage = MeasurementStorage()
    private let imageStorage = ImageStorage()

    // MARK: - Device ID

    /// Get the device identifier for credit tracking
    var deviceId: String {
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            return id
        }
        let key = "ReefBuddy.DeviceID"
        if let storedId = UserDefaults.standard.string(forKey: key) {
            return storedId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    // MARK: - Initialization

    init() {
        // Load tanks from local storage first (works offline)
        tanks = tankStorage.tanks
        if selectedTank == nil, let first = tanks.first {
            selectedTank = first
        }
        
        // Load livestock and measurements from local storage (filtered by selected tank)
        if let tank = selectedTank {
            livestock = livestockStorage.livestock(for: tank.id)
            livestockLogs = livestockStorage.livestockLogs(for: tank.id)
            measurements = measurementStorage.measurements(for: tank.id)
        }
        
        // Load sample data for development (only in DEBUG, after loading from storage)
        #if DEBUG
        // Only load sample data if no tanks in storage
        if tanks.isEmpty {
            loadSampleData()
            // Save sample data to storage
            tankStorage.save(tanks)
            livestockStorage.save(livestock)
            livestockStorage.saveLogs(livestockLogs)
            if let tank = selectedTank {
                measurementStorage.save(measurements, for: tank.id)
            }
        }
        #endif
    }

    // MARK: - Tank Operations

    /// Select a tank and reload its associated data
    func selectTank(_ tank: Tank) {
        selectedTank = tank
        // Reload livestock and measurements for the new tank
        livestock = livestockStorage.livestock(for: tank.id)
        livestockLogs = livestockStorage.livestockLogs(for: tank.id)
        measurements = measurementStorage.measurements(for: tank.id)
        print("📱 Selected tank: \(tank.name) - loaded \(livestock.count) livestock, \(livestockLogs.count) logs, \(measurements.count) measurements")
    }

    /// Fetch all tanks from the backend
    /// Falls back to local storage if API fails
    func fetchTanks() async {
        isLoading = true
        errorMessage = nil

        do {
            // Try to fetch from backend
            let backendTanks = try await apiClient.getTanks()
            tanks = backendTanks
            // Save to local storage
            tankStorage.save(tanks)
            
            if selectedTank == nil, let first = tanks.first {
                selectTank(first)
            }
        } catch {
            // If API fails, use local storage
            print("⚠️ Failed to fetch tanks from backend: \(error.localizedDescription)")
            print("📦 Using local storage instead")
            tanks = tankStorage.tanks

            if selectedTank == nil, let first = tanks.first {
                selectTank(first)
            }
            
            // Only show error if we have no local tanks either
            if tanks.isEmpty {
                errorMessage = "Failed to load tanks: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    /// Create a new tank
    /// Saves to local storage regardless of API success/failure
    func createTank(_ tank: Tank) async {
        isLoading = true
        errorMessage = nil

        do {
            // Try to save to backend
            let newTank = try await apiClient.createTank(tank)
            tanks.append(newTank)
            selectTank(newTank)
            // Save to local storage
            tankStorage.save(newTank)
        } catch {
            // Allow local creation even if API fails (works offline)
            print("⚠️ API create failed, using local storage: \(error.localizedDescription)")
            tanks.append(tank)
            selectTank(tank)
            // Save to local storage
            tankStorage.save(tank)
        }

        isLoading = false
    }

    /// Delete a tank
    /// Removes from local storage regardless of API success/failure
    func deleteTank(_ tank: Tank) async {
        isLoading = true
        errorMessage = nil

        // Try to delete on the server
        do {
            try await apiClient.deleteTank(tank.id)
        } catch {
            // Log API failure but continue with local deletion
            print("⚠️ API delete failed, using local deletion: \(error.localizedDescription)")
        }

        // Remove from local state (always works offline)
        tanks.removeAll { $0.id == tank.id }
        // Remove from local storage
        tankStorage.delete(tank.id)
        
        if selectedTank?.id == tank.id {
            selectedTank = tanks.first
        }

        isLoading = false
    }

    // MARK: - Measurement Operations

    /// Fetch measurements for a specific tank
    /// Falls back to local storage if API fails
    func fetchMeasurements(for tank: Tank) async {
        isLoading = true
        errorMessage = nil

        do {
            // Try to fetch from backend
            let backendMeasurements = try await apiClient.getMeasurements(for: tank.id)
            measurements = backendMeasurements
            // Save to local storage
            measurementStorage.save(backendMeasurements, for: tank.id)
        } catch {
            // If API fails, use local storage
            print("⚠️ Failed to fetch measurements from backend: \(error.localizedDescription)")
            print("📦 Using local storage instead")
            measurements = measurementStorage.measurements(for: tank.id)
            
            // Only show error if we have no local measurements either
            if measurements.isEmpty {
                errorMessage = "Failed to load measurements: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    /// Submit a new measurement
    /// Saves to local storage regardless of API success/failure
    func submitMeasurement(_ measurement: Measurement) async {
        isLoading = true
        errorMessage = nil

        do {
            // Try to save to backend
            let saved = try await apiClient.createMeasurement(measurement)
            measurements.insert(saved, at: 0)
            // Save to local storage
            measurementStorage.save(saved)
        } catch {
            // Allow local save even if API fails (works offline)
            print("⚠️ API save measurement failed, using local storage: \(error.localizedDescription)")
            measurements.insert(measurement, at: 0)
            // Save to local storage
            measurementStorage.save(measurement)
        }

        isLoading = false
    }

    /// Request AI analysis for a measurement
    /// Uses device-based credits (3 free, then paid via IAP)
    func requestAnalysis(for measurement: Measurement, tank: Tank, storeManager: StoreManager, temperatureUnit: String = "F") async -> AnalysisResponse? {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await apiClient.analyzeParameters(
                measurement,
                tankVolume: tank.volumeGallons,
                deviceId: deviceId,
                temperatureUnit: temperatureUnit
            )

            // Update credit balance in StoreManager if available
            if let creditBalance = result.creditBalance {
                print("💰 Analysis completed, updating credit balance: free=\(creditBalance.freeRemaining), paid=\(creditBalance.paidCredits)")
                storeManager.updateCreditBalance(creditBalance)
            } else {
                print("⚠️ Analysis completed but no credit balance in response - decrementing local balance")
                // For development: decrement local credit balance when backend doesn't provide it
                storeManager.decrementLocalCredit()
            }

            isLoading = false
            return result.analysis
        } catch APIError.noCredits {
            // Show purchase credits sheet
            isLoading = false
            showPurchaseCredits = true
            errorMessage = "No analysis credits remaining. Purchase more to continue."
            return nil
        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }

    // MARK: - Livestock Operations

    /// Fetch livestock for a specific tank
    /// Falls back to local storage if API fails
    func fetchLivestock(for tank: Tank) async {
        isLoading = true
        errorMessage = nil

        // Load from local storage first
        livestock = livestockStorage.livestock(for: tank.id)
        
        // TODO: In production, fetch from API and merge with local storage
        // For now, we use local storage only
        
        isLoading = false
    }

    /// Add new livestock
    /// Saves to local storage and handles images
    func addLivestock(_ newLivestock: Livestock) async {
        isLoading = true
        errorMessage = nil

        var livestockToSave = newLivestock
        
        // Save image to file system if present
        if let photoData = newLivestock.photoData {
            if let imagePath = imageStorage.saveImage(photoData, for: newLivestock.id) {
                // Note: We keep photoData in memory for display, but it's also saved to disk
                print("📸 Saved livestock image to: \(imagePath)")
            }
        }

        // Save to local storage first
        livestockStorage.save(livestockToSave)
        
        // Reload from storage to ensure sync (important for TestFlight/persistence)
        if let tank = selectedTank {
            livestock = livestockStorage.livestock(for: tank.id)
        }

        // TODO: In production, call API to save to backend

        isLoading = false
    }

    /// Update existing livestock
    /// Saves to local storage and handles images
    func updateLivestock(_ updatedLivestock: Livestock) async {
        isLoading = true
        errorMessage = nil

        var updated = updatedLivestock
        updated.updatedAt = Date()
        
        // Save image to file system if present
        if let photoData = updated.photoData {
            if let imagePath = imageStorage.saveImage(photoData, for: updated.id) {
                print("📸 Updated livestock image to: \(imagePath)")
            }
        }

        // Find and update the livestock
        if let index = livestock.firstIndex(where: { $0.id == updated.id }) {
            livestock[index] = updated
        }
        
        // Save to local storage
        livestockStorage.save(updated)

        // TODO: In production, call API to update on backend

        isLoading = false
    }

    /// Delete livestock
    /// Removes from local storage and deletes images
    func deleteLivestock(_ livestockToDelete: Livestock) async {
        isLoading = true
        errorMessage = nil

        // Delete image from file system
        imageStorage.deleteImage(for: livestockToDelete.id)

        // Remove from local array
        livestock.removeAll { $0.id == livestockToDelete.id }
        // Also remove related logs
        livestockLogs.removeAll { $0.livestockId == livestockToDelete.id }
        
        // Remove from local storage
        livestockStorage.deleteLivestock(livestockToDelete.id)

        // TODO: In production, call API to delete on backend

        isLoading = false
    }

    /// Add a health log entry for livestock
    /// Saves to local storage and handles images
    func addLivestockLog(_ log: LivestockLog) async {
        isLoading = true
        errorMessage = nil

        var logToSave = log
        
        // Save image to file system if present
        if let photoData = log.photoData {
            if let imagePath = imageStorage.saveImage(photoData, for: log.id) {
                print("📸 Saved log image to: \(imagePath)")
            }
        }

        // Add the log
        livestockLogs.insert(logToSave, at: 0)
        // Save to local storage
        livestockStorage.saveLog(logToSave)

        // Update livestock health status
        if let index = livestock.firstIndex(where: { $0.id == log.livestockId }) {
            var updated = livestock[index]
            updated.healthStatus = log.healthStatus
            updated.updatedAt = Date()
            livestock[index] = updated
            // Save updated livestock
            livestockStorage.save(updated)
        }

        isLoading = false
    }

    /// Fetch health logs for specific livestock
    /// Loads from local storage
    func fetchLivestockLogs(for livestockItem: Livestock) -> [LivestockLog] {
        return livestockStorage.logs(for: livestockItem.id)
    }

    // MARK: - Sample Data (Debug)

    #if DEBUG
    private func loadSampleData() {
        tanks = Tank.samples
        selectedTank = tanks.first
        measurements = Measurement.samples
        livestock = Livestock.samples
        livestockLogs = LivestockLog.samples
    }
    #endif
}
