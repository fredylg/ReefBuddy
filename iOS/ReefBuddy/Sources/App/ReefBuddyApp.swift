import SwiftUI
import UIKit
// UN* delegate parameters are not marked Sendable in the SDK; the async delegate methods on the
// @MainActor AppDelegate hop to the main actor regardless of the calling queue.
@preconcurrency import UserNotifications
import os

let appLog = Logger(subsystem: "au.com.aethers.reefbuddy", category: "App")

/// Development-only diagnostics. Anything interpolated is treated as private by the unified log, and
/// nothing is emitted at all in release builds (I-26). Use `appLog` directly for operational events.
func debugLog(_ items: Any...) {
    #if DEBUG
    let message = items.map { String(describing: $0) }.joined(separator: " ")
    appLog.debug("\(message, privacy: .private)")
    #endif
}

// MARK: - ReefBuddy App

/// Main entry point for the ReefBuddy iOS application.
/// Built with New Brutalist design principles: bold, high-contrast, no compromises.
@main
struct ReefBuddyApp: App {

    // MARK: - State

    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var storeManager = StoreManager()
    @StateObject private var analysisStorage = AnalysisStorage()
    @StateObject private var scheduleStore = MaintenanceScheduleStore()
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
                .environmentObject(scheduleStore)
                .onAppear {
                    // Cold-start taps arrive in the AppDelegate before any view exists; attaching here
                    // flushes anything buffered (I-19).
                    appDelegate.attachMaintenanceTapHandler { userInfo in
                        appState.handleMaintenanceNotification(userInfo: userInfo)
                    }
                    Task {
                        await MaintenanceNotificationService.shared.scheduleAll(scheduleStore.activeSchedules)
                        await scheduleStore.syncPendingBestEffort()
                    }
                }
        }
    }
}

// MARK: - App Delegate (Notifications)

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Notification payloads are string-only (see `MaintenanceNotificationService.notificationContent`), so the
    /// tap is reduced to `[String: String]` in the nonisolated delegate callback and handed to the main actor.
    private var maintenanceTapHandler: (([String: String]) -> Void)?
    private var pendingMaintenanceTap: [String: String]?

    /// The delegate must be in place before launch finishes, or a tap that cold-starts the app is lost.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Register the handler; any tap that arrived before a view existed is delivered immediately.
    func attachMaintenanceTapHandler(_ handler: @escaping ([String: String]) -> Void) {
        maintenanceTapHandler = handler
        if let pending = pendingMaintenanceTap {
            pendingMaintenanceTap = nil
            handler(pending)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        var payload: [String: String] = [:]
        for (key, value) in response.notification.request.content.userInfo {
            if let key = key as? String, let value = value as? String {
                payload[key] = value
            }
        }
        await deliverMaintenanceTap(payload)
    }

    private func deliverMaintenanceTap(_ payload: [String: String]) {
        if let handler = maintenanceTapHandler {
            handler(payload)
        } else {
            pendingMaintenanceTap = payload
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

    /// Water changes for the selected tank
    @Published var waterChanges: [WaterChange] = []

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Show purchase credits sheet when user runs out of credits
    @Published var showPurchaseCredits: Bool = false

    /// Deep link from maintenance reminder notification
    @Published var maintenanceDeepLink: MaintenanceDeepLink?

    /// Latest explicitly logged water change available to link to the next analysis.
    @Published var pendingWaterChangeContext: AnalysisWaterChangeContext?

    // MARK: - Dependencies

    private let apiClient = APIClient()
    private let tankStorage = TankStorage()
    private let livestockStorage = LivestockStorage()
    private let measurementStorage = MeasurementStorage()
    private let waterChangeStorage = WaterChangeStorage()
    private let imageStorage = ImageStorage()

    // MARK: - Device ID

    /// Stable anonymous device identifier (Keychain-backed, see DeviceIdentity).
    var deviceId: String { DeviceIdentity.deviceId }

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
            waterChanges = waterChangeStorage.waterChanges(for: tank.id)
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

    func handleMaintenanceNotification(userInfo: [String: String]) {
        debugLog("🔔 [AppState] handleMaintenanceNotification userInfo: \(userInfo)")
        guard userInfo["kind"] == "maintenance" else {
            debugLog("🔔 [AppState] ignored — kind=\(userInfo["kind"] ?? "nil")")
            return
        }
        guard let scheduleIdStr = userInfo["scheduleId"],
              let tankIdStr = userInfo["tankId"],
              let typeStr = userInfo["type"],
              let scheduleId = UUID(uuidString: scheduleIdStr),
              let tankId = UUID(uuidString: tankIdStr),
              let type = MaintenanceSchedule.ScheduleType(rawValue: typeStr)
        else {
            debugLog("🔔 [AppState] failed to parse deep link payload")
            return
        }
        debugLog("🔔 [AppState] deep link → schedule=\(scheduleIdStr) tank=\(tankIdStr) type=\(typeStr)")
        maintenanceDeepLink = MaintenanceDeepLink(scheduleId: scheduleId, tankId: tankId, type: type)
    }

    // MARK: - Tank Operations

    /// Select a tank and reload its associated data
    func selectTank(_ tank: Tank) {
        selectedTank = tank
        // Reload livestock and measurements for the new tank
        livestock = livestockStorage.livestock(for: tank.id)
        livestockLogs = livestockStorage.livestockLogs(for: tank.id)
        measurements = measurementStorage.measurements(for: tank.id)
        waterChanges = waterChangeStorage.waterChanges(for: tank.id)
        debugLog("📱 Selected tank: \(tank.name) - loaded \(livestock.count) livestock, \(livestockLogs.count) logs, \(measurements.count) measurements, \(waterChanges.count) water changes")
    }

    /// Fetch all tanks from the backend
    /// Falls back to local storage if API fails
    func fetchTanks() async {
        isLoading = true
        errorMessage = nil

        do {
            let backendTanks = try await apiClient.getTanks()
            // Merge by id: the server wins for tanks it knows; tanks that only exist locally are kept.
            let serverIds = Set(backendTanks.map(\.id))
            let localOnly = tankStorage.tanks.filter { !serverIds.contains($0.id) }
            tanks = backendTanks + localOnly
            tankStorage.save(tanks)

            if selectedTank == nil, let first = tanks.first {
                selectTank(first)
            }
        } catch {
            appLog.error("Fetch tanks failed, using local storage: \(error.localizedDescription, privacy: .public)")
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
            debugLog("⚠️ API create failed, using local storage: \(error.localizedDescription)")
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
            debugLog("⚠️ API delete failed, using local deletion: \(error.localizedDescription)")
        }

        // Remove from local state and cascade to everything stored for this tank (I-12)
        tanks.removeAll { $0.id == tank.id }
        tankStorage.delete(tank.id)
        measurementStorage.deleteAll(for: tank.id)
        for item in livestockStorage.livestock(for: tank.id) {
            imageStorage.deleteImage(for: item.id)
            livestockStorage.deleteLivestock(item.id)
        }
        waterChangeStorage.replace([], for: tank.id)
        if selectedTank?.id == tank.id {
            measurements = []
            livestock = []
            livestockLogs = []
            waterChanges = []
        }
        
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
            debugLog("⚠️ Failed to fetch measurements from backend: \(error.localizedDescription)")
            debugLog("📦 Using local storage instead")
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
    @discardableResult
    func submitMeasurement(_ measurement: Measurement) async -> Measurement {
        isLoading = true
        errorMessage = nil

        do {
            // Try to save to backend
            let saved = try await apiClient.createMeasurement(measurement)
            measurements.insert(saved, at: 0)
            // Save to local storage
            measurementStorage.save(saved)
            isLoading = false
            return saved
        } catch {
            // Allow local save even if API fails (works offline)
            debugLog("⚠️ API save measurement failed, using local storage: \(error.localizedDescription)")
            measurements.insert(measurement, at: 0)
            // Save to local storage
            measurementStorage.save(measurement)
            isLoading = false
            return measurement
        }
    }

    /// Fetch completed water changes for a tank. Falls back to local storage when offline.
    func fetchWaterChanges(for tank: Tank) async {
        waterChanges = waterChangeStorage.waterChanges(for: tank.id)

        do {
            let serverChanges = try await apiClient.getWaterChanges(for: tank.id)
            waterChangeStorage.replace(serverChanges, for: tank.id)
            waterChanges = waterChangeStorage.waterChanges(for: tank.id)
        } catch {
            debugLog("⚠️ Failed to fetch water changes from backend: \(error.localizedDescription)")
        }
    }

    /// Log a water change locally first, then best-effort sync to the backend.
    @discardableResult
    func logWaterChange(_ waterChange: WaterChange) async -> WaterChange {
        var local = waterChange
        local.updatedAt = Date()
        local.needsSync = true
        waterChangeStorage.save(local)
        if selectedTank?.id == local.tankId {
            waterChanges = waterChangeStorage.waterChanges(for: local.tankId)
        }

        do {
            let saved = try await apiClient.createWaterChange(local)
            waterChangeStorage.save(saved)
            if selectedTank?.id == saved.tankId {
                waterChanges = waterChangeStorage.waterChanges(for: saved.tankId)
            }
            pendingWaterChangeContext = AnalysisWaterChangeContext(id: saved.id, tankId: saved.tankId)
            return saved
        } catch {
            debugLog("⚠️ API water change save failed, using local storage: \(error.localizedDescription)")
            pendingWaterChangeContext = AnalysisWaterChangeContext(id: local.id, tankId: local.tankId)
            return local
        }
    }

    func recentWaterChanges(for tankId: UUID) -> [WaterChange] {
        waterChangeStorage.waterChanges(for: tankId)
    }

    func matchingWaterChangeId(for tankId: UUID, analyzedAt: Date = Date()) -> UUID? {
        if let pending = pendingWaterChangeContext, pending.tankId == tankId {
            return pending.id
        }

        let cutoff = analyzedAt.addingTimeInterval(-96 * 60 * 60)
        return waterChangeStorage
            .waterChanges(for: tankId)
            .filter { $0.performedAt >= cutoff && $0.performedAt <= analyzedAt }
            .sorted { $0.performedAt > $1.performedAt }
            .first?
            .id
    }

    func clearPendingWaterChangeIfMatched(_ waterChangeId: UUID?) {
        guard let waterChangeId,
              pendingWaterChangeContext?.id == waterChangeId else { return }
        pendingWaterChangeContext = nil
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
                debugLog("💰 Analysis completed, updating credit balance: free=\(creditBalance.freeRemaining), paid=\(creditBalance.paidCredits)")
                storeManager.updateCreditBalance(creditBalance)
            } else {
                appLog.error("Analysis response carried no credit balance; refreshing from the server")
                await storeManager.fetchCreditBalance()
            }

            if result.truncated {
                errorMessage = "The analysis was longer than expected and may be incomplete."
            }
            isLoading = false
            return result.analysis
        } catch APIError.analysisRefused(let message) {
            isLoading = false
            errorMessage = message
            return nil
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
        
        // Fetch from API and merge with local storage (retroactive to app 1.0.1 - uses device-based auth)
        do {
            let serverLivestock = try await apiClient.getLivestock(for: tank.id)
            // Merge server data with local storage
            for serverItem in serverLivestock {
                livestockStorage.save(serverItem)
            }
            // Reload from storage to get merged data
            livestock = livestockStorage.livestock(for: tank.id)
        } catch {
            debugLog("⚠️ Failed to fetch livestock from backend: \(error.localizedDescription)")
            // Continue with local storage only
        }
        
        isLoading = false
    }

    /// Add new livestock
    /// Saves to local storage and handles images
    func addLivestock(_ newLivestock: Livestock) async {        isLoading = true
        errorMessage = nil

        let livestockToSave = newLivestock
        
        // Save image to file system if present
        if let photoData = newLivestock.photoData {
            if let imagePath = imageStorage.saveImage(photoData, for: newLivestock.id) {
                // Note: We keep photoData in memory for display, but it's also saved to disk
                debugLog("📸 Saved livestock image to: \(imagePath)")
            }
        }

        // Save to local storage first
        livestockStorage.save(livestockToSave)        // Reload from storage to ensure sync (important for TestFlight/persistence)
        if let tank = selectedTank {
            livestock = livestockStorage.livestock(for: tank.id)
        }

        // Call API to save to backend (retroactive to app 1.0.1 - uses device-based auth)
        do {            let savedLivestock = try await apiClient.createLivestock(newLivestock, for: newLivestock.tankId)            // Update local storage with server response (in case server generated different ID)
            livestockStorage.save(savedLivestock)
            if let tank = selectedTank {
                livestock = livestockStorage.livestock(for: tank.id)
            }
        } catch {            // Log error but don't fail - local storage already saved
            debugLog("⚠️ Failed to save livestock to backend: \(error.localizedDescription)")
            errorMessage = "Saved locally, but failed to sync with server: \(error.localizedDescription)"
        }

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
                debugLog("📸 Updated livestock image to: \(imagePath)")
            }
        }

        // Find and update the livestock
        if let index = livestock.firstIndex(where: { $0.id == updated.id }) {
            livestock[index] = updated
        }
        
        // Save to local storage
        livestockStorage.save(updated)

        // Call API to update on backend (retroactive to app 1.0.1 - uses device-based auth)
        do {
            let savedLivestock = try await apiClient.updateLivestock(updated)
            // Update local storage with server response
            livestockStorage.save(savedLivestock)
            if let index = livestock.firstIndex(where: { $0.id == savedLivestock.id }) {
                livestock[index] = savedLivestock
            }
        } catch APIError.notFound {
            // If update fails with 404, try creating the livestock (retroactive compatibility)
            // This handles the case where livestock was created locally but never synced to server
            debugLog("⚠️ Livestock not found on server, attempting to create it");
            do {
                let createdLivestock = try await apiClient.createLivestock(updated, for: updated.tankId)
                // Update local storage with server response
                livestockStorage.save(createdLivestock)
                if let index = livestock.firstIndex(where: { $0.id == createdLivestock.id }) {
                    livestock[index] = createdLivestock
                } else {
                    // If ID changed, add the new one
                    livestock.append(createdLivestock)
                }
            } catch let createError {
                debugLog("⚠️ Failed to create livestock on backend: \(createError.localizedDescription)")
                errorMessage = "Updated locally, but failed to sync with server: \(createError.localizedDescription)"
            }
        } catch let error {
            debugLog("⚠️ Failed to update livestock on backend: \(error.localizedDescription)")
            errorMessage = "Updated locally, but failed to sync with server: \(error.localizedDescription)"
        }

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

        // Call API to delete on backend (retroactive to app 1.0.1 - uses device-based auth)
        do {
            try await apiClient.deleteLivestock(livestockToDelete.id)
        } catch {
            debugLog("⚠️ Failed to delete livestock on backend: \(error.localizedDescription)")
            errorMessage = "Deleted locally, but failed to sync with server: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Add a health log entry for livestock
    /// Saves to local storage and handles images
    func addLivestockLog(_ log: LivestockLog) async {
        isLoading = true
        errorMessage = nil

        let logToSave = log
        
        // Save image to file system if present
        if let photoData = log.photoData {
            if let imagePath = imageStorage.saveImage(photoData, for: log.id) {
                debugLog("📸 Saved log image to: \(imagePath)")
            }
        }

        // Add the log to local array first (optimistic update)
        livestockLogs.insert(logToSave, at: 0)
        // Don't save to storage yet - wait for server response to avoid duplicates

        // Update livestock health status
        if let index = livestock.firstIndex(where: { $0.id == log.livestockId }) {
            var updated = livestock[index]
            updated.healthStatus = log.healthStatus
            updated.updatedAt = Date()
            livestock[index] = updated
            // Save updated livestock
            livestockStorage.save(updated)
        }

        // Call API to save to backend (retroactive to app 1.0.1 - uses device-based auth)
        do {
            let savedLog = try await apiClient.createLivestockLog(log)
            // Remove the old log from array and storage if ID changed
            if savedLog.id != log.id {
                livestockLogs.removeAll { $0.id == log.id }
                // Also remove from storage to prevent duplicates
                livestockStorage.deleteLog(log.id)
            }
            // Update or insert the saved log in array
            if let index = livestockLogs.firstIndex(where: { $0.id == savedLog.id }) {
                livestockLogs[index] = savedLog
            } else {
                // If not found, insert at the beginning (newest first)
                livestockLogs.insert(savedLog, at: 0)
            }
            // Now save to storage with the server response (single source of truth)
            livestockStorage.saveLog(savedLog)
        } catch {
            // If API call fails, save the local log to storage as fallback
            livestockStorage.saveLog(logToSave)
            debugLog("⚠️ Failed to save livestock log to backend: \(error.localizedDescription)")
            errorMessage = "Saved locally, but failed to sync with server: \(error.localizedDescription)"
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
