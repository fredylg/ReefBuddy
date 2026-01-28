import Foundation
import UIKit
import DeviceCheck

// MARK: - API Client

/// Network client for communicating with the ReefBuddy Cloudflare Workers backend.
/// Handles all API requests for tanks, measurements, and AI analysis.
actor APIClient {

    // MARK: - Configuration

    /// Production API URL (Cloudflare Worker)
    private static let productionURL = "https://reefbuddy.fredylg.workers.dev"
    
    /// Local development API URL (for wrangler dev)
    private static let localDevURL = "http://localhost:8787"

    /// Base URL for the API (Cloudflare Worker)
    private let baseURL: URL

    /// URL session for network requests
    private let session: URLSession

    /// JSON encoder with snake_case conversion
    private let encoder: JSONEncoder

    /// JSON decoder with snake_case conversion
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(baseURL: URL? = nil) {
        // Priority: 1) Passed URL, 2) Environment variable, 3) Debug build uses localhost, 4) Production URL
        if let baseURL = baseURL {
            self.baseURL = baseURL
        } else if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"],
                  let url = URL(string: envURL) {
            self.baseURL = url
        } else {
            // Use localhost for debug builds (simulator testing), production URL for release builds
            #if DEBUG
            self.baseURL = URL(string: Self.localDevURL)!
            #else
            self.baseURL = URL(string: Self.productionURL)!
            #endif
        }

        // Configure URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        // Configure JSON coding
        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Tank Endpoints

    /// Fetch all tanks for the current user
    func getTanks() async throws -> [Tank] {
        let url = baseURL.appendingPathComponent("api/tanks")
        let request = makeRequest(url: url, method: "GET")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<[Tank]>.self, from: data)
        return apiResponse.data
    }

    /// Get a specific tank by ID
    func getTank(id: UUID) async throws -> Tank {
        let url = baseURL.appendingPathComponent("api/tanks/\(id.uuidString)")
        let request = makeRequest(url: url, method: "GET")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Tank>.self, from: data)
        return apiResponse.data
    }

    /// Create a new tank
    func createTank(_ tank: Tank) async throws -> Tank {
        let url = baseURL.appendingPathComponent("api/tanks")
        var request = makeRequest(url: url, method: "POST")
        request.httpBody = try encoder.encode(tank)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Tank>.self, from: data)
        return apiResponse.data
    }

    /// Update an existing tank
    func updateTank(_ tank: Tank) async throws -> Tank {
        let url = baseURL.appendingPathComponent("api/tanks/\(tank.id.uuidString)")
        var request = makeRequest(url: url, method: "PUT")
        request.httpBody = try encoder.encode(tank)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Tank>.self, from: data)
        return apiResponse.data
    }

    /// Delete a tank
    func deleteTank(_ id: UUID) async throws {
        let url = baseURL.appendingPathComponent("api/tanks/\(id.uuidString)")
        let request = makeRequest(url: url, method: "DELETE")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Measurement Endpoints

    /// Fetch all measurements for a tank
    func getMeasurements(for tankId: UUID, limit: Int = 50) async throws -> [Measurement] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/measurements"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "tank_id", value: tankId.uuidString),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        let request = makeRequest(url: components.url!, method: "GET")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<[Measurement]>.self, from: data)
        return apiResponse.data
    }

    /// Create a new measurement
    func createMeasurement(_ measurement: Measurement) async throws -> Measurement {
        let url = baseURL.appendingPathComponent("api/measurements")
        var request = makeRequest(url: url, method: "POST")

        let requestBody = CreateMeasurementRequest(from: measurement)
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Measurement>.self, from: data)
        return apiResponse.data
    }

    // MARK: - AI Analysis Endpoint

    /// Request AI analysis of water parameters
    /// This endpoint routes through Cloudflare AI Gateway to Claude
    /// Requires device credits (3 free, then paid)
    /// Includes DeviceCheck token for device attestation
    func analyzeParameters(_ measurement: Measurement, tankVolume: Double, deviceId: String, temperatureUnit: String = "F") async throws -> AnalysisResult {
        let url = baseURL.appendingPathComponent("analyze")
        var request = makeRequest(url: url, method: "POST")

        // Generate DeviceCheck token for device attestation
        let deviceToken = await generateDeviceToken()        // Use a plain JSON encoder for this endpoint (Worker expects camelCase, not snake_case)
        let analysisEncoder = JSONEncoder()
        analysisEncoder.dateEncodingStrategy = .iso8601

        let requestBody = AnalysisRequest(
            measurement: measurement,
            tankVolume: tankVolume,
            deviceId: deviceId,
            deviceToken: deviceToken,
            isDevelopment: isDebugBuild(),
            temperatureUnit: temperatureUnit
        )
        
        // Debug logging: Log the measurement notes before encoding
        print("📝 Measurement notes: \(measurement.notes ?? "nil")")
        print("📝 Request body parameters.notes: \(requestBody.parameters.notes ?? "nil")")
        
        request.httpBody = try analysisEncoder.encode(requestBody)
        
        // Debug logging: Log the encoded JSON
        if let jsonData = request.httpBody,
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Sending to Cloudflare: \(jsonString)")
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        // Parse the Worker's response format (also uses camelCase)
        let analysisDecoder = JSONDecoder()
        analysisDecoder.dateDecodingStrategy = .iso8601
        let apiResponse = try analysisDecoder.decode(AnalyzeAPIResponse.self, from: data)

        // Debug log the response
        print("🔍 API Response - success: \(apiResponse.success), creditsRemaining: \(apiResponse.creditsRemaining ?? -1), freeRemaining: \(apiResponse.freeRemaining ?? -1), paidCredits: \(apiResponse.paidCredits ?? -1)")

        if let analysis = apiResponse.analysis {
            // Create credit balance if available
            let creditBalance: CreditBalance?
            if let freeRemaining = apiResponse.freeRemaining,
               let paidCredits = apiResponse.paidCredits,
               let creditsRemaining = apiResponse.creditsRemaining {
                // Note: totalAnalyses is not provided in analysis response, so we use a placeholder
                // The StoreManager will merge this with existing data if needed
                creditBalance = CreditBalance(
                    freeRemaining: freeRemaining,
                    paidCredits: paidCredits,
                    totalCredits: creditsRemaining,
                    totalAnalyses: -1 // Use -1 to indicate this field should be preserved from existing balance
                )
            } else {
                creditBalance = nil
            }

            return AnalysisResult(
                analysis: analysis.toAnalysisResponse(),
                creditBalance: creditBalance
            )
        } else {
            throw APIError.invalidResponse
        }
    }

    // MARK: - DeviceCheck

    /// Generate a DeviceCheck token for device attestation
    /// Returns nil if DeviceCheck is not supported on this device
    private func generateDeviceToken() async -> String? {
        guard DCDevice.current.isSupported else {
            print("DeviceCheck not supported on this device")
            return nil
        }

        return await withCheckedContinuation { continuation in
            DCDevice.current.generateToken { data, error in                if let error = error {
                    print("DeviceCheck token generation failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else if let data = data {
                    continuation.resume(returning: data.base64EncodedString())
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Check if this is a debug/development build
    private func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Livestock Endpoints

    /// Create new livestock for a tank
    func createLivestock(_ livestock: Livestock, for tankId: UUID) async throws -> Livestock {
        let url = baseURL.appendingPathComponent("api/tanks/\(tankId.uuidString)/livestock")
        var request = makeRequest(url: url, method: "POST")
        
        // Use camelCase for livestock creation (backend expects camelCase, not snake_case)
        let livestockEncoder = JSONEncoder()
        livestockEncoder.dateEncodingStrategy = .iso8601
        // Note: No keyEncodingStrategy set, so it uses camelCase by default
        
        let requestBody = CreateLivestockRequest(from: livestock)
        request.httpBody = try livestockEncoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        // Parse response - backend returns {success: true, livestock: {...}} with snake_case keys
        let responseWrapper = try decoder.decode(LivestockCreateResponse.self, from: data)
        return convertDBRecordToLivestock(responseWrapper.livestock, tankId: tankId)
    }

    /// Get all livestock for a tank
    func getLivestock(for tankId: UUID) async throws -> [Livestock] {
        let url = baseURL.appendingPathComponent("api/tanks/\(tankId.uuidString)/livestock")
        let request = makeRequest(url: url, method: "GET")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(LivestockListResponse.self, from: data)
        return apiResponse.livestock.map { convertDBRecordToLivestock($0, tankId: tankId) }
    }

    /// Update existing livestock
    func updateLivestock(_ livestock: Livestock) async throws -> Livestock {
        let url = baseURL.appendingPathComponent("api/livestock/\(livestock.id.uuidString)")
        var request = makeRequest(url: url, method: "PUT")
        
        // Use camelCase for livestock update
        let livestockEncoder = JSONEncoder()
        livestockEncoder.dateEncodingStrategy = .iso8601
        
        let requestBody = UpdateLivestockRequest(from: livestock)
        request.httpBody = try livestockEncoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let responseWrapper = try decoder.decode(LivestockUpdateResponse.self, from: data)
        return convertDBRecordToLivestock(responseWrapper.livestock, tankId: livestock.tankId)
    }
    
    /// Create a livestock log entry
    func createLivestockLog(_ log: LivestockLog) async throws -> LivestockLog {
        let url = baseURL.appendingPathComponent("api/livestock/\(log.livestockId.uuidString)/logs")
        var request = makeRequest(url: url, method: "POST")
        
        // Map iOS healthStatus to backend logType
        let logType: String
        switch log.healthStatus {
        case .deceased:
            logType = "death"
        case .critical, .declining:
            logType = "treatment"
        case .thriving, .healthy, .stressed:
            logType = "observation"
        }
        
        // Convert Date to ISO 8601 string
        let formatter = ISO8601DateFormatter()
        let loggedAtString = formatter.string(from: log.loggedAt)
        
        // Create request body
        struct LivestockLogRequest: Codable {
            let logType: String
            let description: String?
            let loggedAt: String
        }
        
        let requestBody = LivestockLogRequest(
            logType: logType,
            description: log.notes,
            loggedAt: loggedAtString
        )
        
        let logEncoder = JSONEncoder()
        logEncoder.dateEncodingStrategy = .iso8601
        request.httpBody = try logEncoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        // Parse response - backend returns {success: true, log: {...}} with snake_case keys
        struct LivestockLogResponse: Codable {
            let success: Bool
            let log: LogRecord
            
            struct LogRecord: Codable {
                let id: String
                let livestockId: String
                let logType: String
                let description: String?
                let loggedAt: String
                let createdAt: String
            }
        }
        
        let logDecoder = JSONDecoder()
        logDecoder.keyDecodingStrategy = .convertFromSnakeCase
        logDecoder.dateDecodingStrategy = .iso8601
        let responseWrapper = try logDecoder.decode(LivestockLogResponse.self, from: data)
        let logRecord = responseWrapper.log
        
        // Convert back to iOS LivestockLog model
        guard let logId = UUID(uuidString: logRecord.id),
              let livestockId = UUID(uuidString: logRecord.livestockId),
              let loggedAt = formatter.date(from: logRecord.loggedAt) else {
            throw APIError.decodingError(NSError(domain: "LivestockLog", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse log response"]))
        }
        
        // Map backend logType back to healthStatus (approximate)
        let healthStatus: HealthStatus
        switch logRecord.logType {
        case "death":
            healthStatus = .deceased
        case "treatment":
            healthStatus = log.healthStatus // Keep original if treatment
        default:
            healthStatus = log.healthStatus // Keep original for observation/feeding
        }
        
        return LivestockLog(
            id: logId,
            livestockId: livestockId,
            loggedAt: loggedAt,
            healthStatus: healthStatus,
            notes: logRecord.description
        )
    }
    
    /// Convert backend DB record to iOS Livestock model
    private func convertDBRecordToLivestock(_ record: LivestockCreateResponse.LivestockDBRecord, tankId: UUID) -> Livestock {
        return convertDBRecordToLivestockGeneric(
            id: record.id,
            tankId: record.tankId,
            name: record.name,
            species: record.species,
            category: record.category,
            quantity: record.quantity,
            purchaseDate: record.purchaseDate,
            purchasePrice: record.purchasePrice,
            healthStatus: record.healthStatus,
            notes: record.notes,
            addedAt: record.addedAt,
            createdAt: record.createdAt,
            fallbackTankId: tankId
        )
    }
    
    /// Convert backend DB record to iOS Livestock model (for list responses)
    private func convertDBRecordToLivestock(_ record: LivestockListResponse.LivestockDBRecord, tankId: UUID) -> Livestock {
        return convertDBRecordToLivestockGeneric(
            id: record.id,
            tankId: record.tankId,
            name: record.name,
            species: record.species,
            category: record.category,
            quantity: record.quantity,
            purchaseDate: record.purchaseDate,
            purchasePrice: record.purchasePrice,
            healthStatus: record.healthStatus,
            notes: record.notes,
            addedAt: record.addedAt,
            createdAt: record.createdAt,
            fallbackTankId: tankId
        )
    }
    
    /// Convert backend DB record to iOS Livestock model (for update response)
    private func convertDBRecordToLivestock(_ record: LivestockUpdateResponse.LivestockDBRecord, tankId: UUID) -> Livestock {
        return convertDBRecordToLivestockGeneric(
            id: record.id,
            tankId: record.tankId,
            name: record.name,
            species: record.species,
            category: record.category,
            quantity: record.quantity,
            purchaseDate: record.purchaseDate,
            purchasePrice: record.purchasePrice,
            healthStatus: record.healthStatus,
            notes: record.notes,
            addedAt: record.addedAt,
            createdAt: record.createdAt,
            fallbackTankId: tankId
        )
    }
    
    /// Generic conversion function for all DB record types
    private func convertDBRecordToLivestockGeneric(
        id: String,
        tankId: String,
        name: String,
        species: String?,
        category: String?,
        quantity: Int,
        purchaseDate: String?,
        purchasePrice: Double?,
        healthStatus: String?,
        notes: String?,
        addedAt: String,
        createdAt: String,
        fallbackTankId: UUID
    ) -> Livestock {
        let formatter = ISO8601DateFormatter()
        let purchaseDateValue = purchaseDate.flatMap { formatter.date(from: $0) } ?? Date()
        let createdAtValue = formatter.date(from: createdAt) ?? Date()
        
        // Convert backend category (SPS, LPS, Soft, Fish, Invertebrate) to iOS enum
        let categoryValue: LivestockCategory
        switch category?.uppercased() {
        case "SPS":
            categoryValue = .sps
        case "LPS":
            categoryValue = .lps
        case "SOFT":
            categoryValue = .softCoral
        case "FISH":
            categoryValue = .fish
        case "INVERTEBRATE":
            categoryValue = .invertebrate
        default:
            categoryValue = .other
        }
        
        // Convert backend health status to iOS enum
        // Backend: healthy, sick, deceased, quarantine
        // iOS: thriving, healthy, stressed, declining, critical, deceased
        let healthStatusValue: HealthStatus
        switch healthStatus?.lowercased() {
        case "healthy":
            healthStatusValue = .healthy
        case "sick":
            healthStatusValue = .stressed  // Map "sick" to "stressed" (closest match)
        case "deceased":
            healthStatusValue = .deceased
        case "quarantine":
            healthStatusValue = .stressed  // Map "quarantine" to "stressed" (closest match)
        default:
            healthStatusValue = .healthy
        }
        
        return Livestock(
            id: UUID(uuidString: id) ?? UUID(),
            tankId: UUID(uuidString: tankId) ?? fallbackTankId,
            name: name,
            scientificName: species,
            category: categoryValue,
            healthStatus: healthStatusValue,
            quantity: quantity,
            purchaseDate: purchaseDateValue,
            purchasePrice: purchasePrice,
            photoData: nil,
            notes: notes,
            createdAt: createdAtValue,
            updatedAt: createdAtValue
        )
    }

    /// Delete livestock
    func deleteLivestock(_ id: UUID) async throws {
        let url = baseURL.appendingPathComponent("api/livestock/\(id.uuidString)")
        let request = makeRequest(url: url, method: "DELETE")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Credits Endpoints

    /// Get the device's credit balance
    func getCreditsBalance(deviceId: String) async throws -> CreditsBalanceResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("credits/balance"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "deviceId", value: deviceId)
        ]

        let request = makeRequest(url: components.url!, method: "GET")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try decoder.decode(CreditsBalanceResponse.self, from: data)
    }

    /// Purchase credits using StoreKit 2 JWS transaction
    func purchaseCredits(
        deviceId: String,
        jwsRepresentation: String,
        transactionId: String,
        originalTransactionId: String,
        productId: String
    ) async throws -> CreditsPurchaseResponse {
        let url = baseURL.appendingPathComponent("credits/purchase")
        var request = makeRequest(url: url, method: "POST")

        // Use camelCase for credits purchase (backend expects camelCase, not snake_case)
        let creditsEncoder = JSONEncoder()
        creditsEncoder.dateEncodingStrategy = .iso8601
        // Note: No keyEncodingStrategy set, so it uses camelCase by default

        let requestBody = CreditsPurchaseRequest(
            deviceId: deviceId,
            jwsRepresentation: jwsRepresentation,
            transactionId: transactionId,
            originalTransactionId: originalTransactionId,
            productId: productId
        )
        request.httpBody = try creditsEncoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try decoder.decode(CreditsPurchaseResponse.self, from: data)
    }

    // MARK: - Private Helpers

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add device identifier for tracking (anonymous)
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }

        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw APIError.badRequest
        case 401:
            throw APIError.unauthorized
        case 402:
            throw APIError.noCredits
        case 403:
            // Check for specific error code in response body
            // For now, default to deviceCheckRequired for 403s from analysis endpoints
            throw APIError.deviceCheckRequired
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        case 503:
            throw APIError.serviceUnavailable
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.unknown(httpResponse.statusCode)
        }
    }
}

// MARK: - API Response Wrapper

/// Standard API response wrapper
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
    let message: String?
}

// MARK: - Credits Models

/// Request body for purchasing credits (StoreKit 2 JWS format)
struct CreditsPurchaseRequest: Codable {
    let deviceId: String
    let jwsRepresentation: String      // StoreKit 2 signed transaction
    let transactionId: String          // Transaction ID from StoreKit 2
    let originalTransactionId: String  // Original transaction ID
    let productId: String
}

/// Response from credits balance endpoint
struct CreditsBalanceResponse: Codable {
    let success: Bool
    let deviceId: String
    let freeLimit: Int
    let freeUsed: Int
    let freeRemaining: Int
    let paidCredits: Int
    let totalCredits: Int
    let totalAnalyses: Int
}

/// Response from credits purchase endpoint
struct CreditsPurchaseResponse: Codable {
    let success: Bool
    let creditsAdded: Int
    let newBalance: NewBalanceInfo

    struct NewBalanceInfo: Codable {
        let freeRemaining: Int
        let paidCredits: Int
        let totalCredits: Int
    }
}

// MARK: - Credit Balance

/// Credit balance information
struct CreditBalance: Codable {
    let freeRemaining: Int
    let paidCredits: Int
    let totalCredits: Int
    let totalAnalyses: Int

    var hasCredits: Bool {
        totalCredits > 0
    }
}

// MARK: - Analysis Result

/// Combined result from analysis endpoint (analysis + credit balance)
struct AnalysisResult {
    let analysis: AnalysisResponse
    let creditBalance: CreditBalance?
}

// MARK: - API Errors

/// API error types
enum APIError: LocalizedError {
    case invalidResponse
    case badRequest
    case unauthorized
    case noCredits
    case forbidden
    case deviceCheckRequired
    case notFound
    case rateLimited
    case serviceUnavailable
    case serverError(Int)
    case unknown(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest:
            return "Invalid request. Please check your input."
        case .unauthorized:
            return "Authentication required"
        case .noCredits:
            return "No analysis credits remaining. Purchase more to continue."
        case .forbidden:
            return "Access denied"
        case .deviceCheckRequired:
            return "Please update to the latest app version to continue."
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please wait and try again."
        case .serviceUnavailable:
            return "Service temporarily unavailable. Please try again in a moment."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .unknown(let code):
            return "Unexpected error (\(code))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
