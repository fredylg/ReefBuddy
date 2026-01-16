import SwiftUI

// MARK: - ReefBuddy App

/// Main entry point for the ReefBuddy iOS application.
/// Built with New Brutalist design principles: bold, high-contrast, no compromises.
@main
struct ReefBuddyApp: App {

    // MARK: - State

    @StateObject private var appState = AppState()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
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

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Number of free analyses remaining this month
    @Published var freeAnalysesRemaining: Int = 3

    // MARK: - API Client

    private let apiClient = APIClient()

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
            errorMessage = "Failed to create tank: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Delete a tank
    func deleteTank(_ tank: Tank) async {
        isLoading = true
        errorMessage = nil

        do {
            try await apiClient.deleteTank(tank.id)
            tanks.removeAll { $0.id == tank.id }
            if selectedTank?.id == tank.id {
                selectedTank = tanks.first
            }
        } catch {
            errorMessage = "Failed to delete tank: \(error.localizedDescription)"
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
            errorMessage = "Failed to save measurement: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Request AI analysis for a measurement
    func requestAnalysis(for measurement: Measurement) async -> AnalysisResponse? {
        guard freeAnalysesRemaining > 0 else {
            errorMessage = "No free analyses remaining. Upgrade to Premium for unlimited access."
            return nil
        }

        isLoading = true
        errorMessage = nil

        do {
            let analysis = try await apiClient.analyzeParameters(measurement)
            freeAnalysesRemaining -= 1
            isLoading = false
            return analysis
        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }

    // MARK: - Sample Data (Debug)

    #if DEBUG
    private func loadSampleData() {
        tanks = Tank.samples
        selectedTank = tanks.first
        measurements = Measurement.samples
    }
    #endif
}
