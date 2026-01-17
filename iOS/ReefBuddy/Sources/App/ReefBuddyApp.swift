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
        // Load sample data for development
        #if DEBUG
        loadSampleData()
        #endif
    }

    // MARK: - Tank Operations

    /// Fetch all tanks from the backend
    func fetchTanks() async {
        isLoading = true
        errorMessage = nil

        do {
            tanks = try await apiClient.getTanks()
            if selectedTank == nil, let first = tanks.first {
                selectedTank = first
            }
        } catch {
            errorMessage = "Failed to load tanks: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Create a new tank
    func createTank(_ tank: Tank) async {
        isLoading = true
        errorMessage = nil

        do {
            let newTank = try await apiClient.createTank(tank)
            tanks.append(newTank)
            selectedTank = newTank
        } catch {
            // Allow local creation even if API fails (works offline)
            print("API create failed, using local storage: \(error.localizedDescription)")
            tanks.append(tank)
            selectedTank = tank
        }

        isLoading = false
    }

    /// Delete a tank
    func deleteTank(_ tank: Tank) async {
        isLoading = true
        errorMessage = nil

        // Try to delete on the server
        do {
            try await apiClient.deleteTank(tank.id)
        } catch {
            // Log API failure but continue with local deletion
            print("API delete failed, using local deletion: \(error.localizedDescription)")
        }

        // Remove from local state (always works offline)
        tanks.removeAll { $0.id == tank.id }
        if selectedTank?.id == tank.id {
            selectedTank = tanks.first
        }

        isLoading = false
    }

    // MARK: - Measurement Operations

    /// Fetch measurements for a specific tank
    func fetchMeasurements(for tank: Tank) async {
        isLoading = true
        errorMessage = nil

        do {
            measurements = try await apiClient.getMeasurements(for: tank.id)
        } catch {
            errorMessage = "Failed to load measurements: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Submit a new measurement
    func submitMeasurement(_ measurement: Measurement) async {
        isLoading = true
        errorMessage = nil

        do {
            let saved = try await apiClient.createMeasurement(measurement)
            measurements.insert(saved, at: 0)
        } catch {
            // Allow local save even if API fails (works offline)
            print("API save measurement failed, using local storage: \(error.localizedDescription)")
            measurements.insert(measurement, at: 0)
        }

        isLoading = false
    }

    /// Request AI analysis for a measurement
    /// Uses device-based credits (3 free, then paid via IAP)
    func requestAnalysis(for measurement: Measurement, tank: Tank, storeManager: StoreManager) async -> AnalysisResponse? {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await apiClient.analyzeParameters(
                measurement,
                tankVolume: tank.volumeGallons,
                deviceId: deviceId
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
    func fetchLivestock(for tank: Tank) async {
        isLoading = true
        errorMessage = nil

        // For now, filter from local data - in production would fetch from API
        livestock = livestock.filter { $0.tankId == tank.id }

        isLoading = false
    }

    /// Add new livestock
    func addLivestock(_ newLivestock: Livestock) async {
        isLoading = true
        errorMessage = nil

        // In production, this would call the API
        // For now, add to local array
        livestock.append(newLivestock)

        isLoading = false
    }

    /// Update existing livestock
    func updateLivestock(_ updatedLivestock: Livestock) async {
        isLoading = true
        errorMessage = nil

        // Find and update the livestock
        if let index = livestock.firstIndex(where: { $0.id == updatedLivestock.id }) {
            var updated = updatedLivestock
            updated.updatedAt = Date()
            livestock[index] = updated
        }

        isLoading = false
    }

    /// Delete livestock
    func deleteLivestock(_ livestockToDelete: Livestock) async {
        isLoading = true
        errorMessage = nil

        // Remove from local array - in production would call API
        livestock.removeAll { $0.id == livestockToDelete.id }
        // Also remove related logs
        livestockLogs.removeAll { $0.livestockId == livestockToDelete.id }

        isLoading = false
    }

    /// Add a health log entry for livestock
    func addLivestockLog(_ log: LivestockLog) async {
        isLoading = true
        errorMessage = nil

        // Add the log
        livestockLogs.insert(log, at: 0)

        // Update livestock health status
        if let index = livestock.firstIndex(where: { $0.id == log.livestockId }) {
            var updated = livestock[index]
            updated.healthStatus = log.healthStatus
            updated.updatedAt = Date()
            livestock[index] = updated
        }

        isLoading = false
    }

    /// Fetch health logs for specific livestock
    func fetchLivestockLogs(for livestockItem: Livestock) -> [LivestockLog] {
        return livestockLogs.filter { $0.livestockId == livestockItem.id }
            .sorted { $0.loggedAt > $1.loggedAt }
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
